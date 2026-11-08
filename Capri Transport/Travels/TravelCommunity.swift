import CryptoKit
import Foundation
import Security
import Observation
import UIKit

// MARK: - Моделі

struct TravelUserRecord: Codable, Identifiable, Equatable {
    let id: UUID
    var displayName: String
    var email: String
    var passwordSalt: Data
    var passwordHash: Data
    let createdAt: Date
}

struct TravelStoryRecord: Codable, Identifiable, Equatable {
    let id: UUID
    let authorId: UUID
    var authorDisplayName: String
    var title: String
    var body: String
    var photoNames: [String]
    let createdAt: Date
}

struct TravelCommentRecord: Codable, Identifiable, Equatable {
    let id: UUID
    let storyId: UUID
    let authorId: UUID
    var authorDisplayName: String
    var text: String
    let createdAt: Date
}

private struct TravelCommunityFile: Codable {
    var users: [TravelUserRecord] = []
    var stories: [TravelStoryRecord] = []
    var storyLikes: [UUID: [UUID]] = [:]
    var comments: [TravelCommentRecord] = []
}

enum TravelAuthError: Error, Equatable {
    case emailTaken
    case invalidCredentials
    case weakPassword
    case invalidDisplayName
    case invalidEmail
    case notSignedIn
    case notYourStory
    case notYourComment
    case emptyComment
    case emptyTitle
}

// MARK: - Сховище (офлайн, спільна стрічка на пристрої)

@Observable
final class TravelStore {
    private(set) var users: [TravelUserRecord] = []
    private(set) var stories: [TravelStoryRecord] = []
    private(set) var storyLikes: [UUID: [UUID]] = [:]
    private(set) var comments: [TravelCommentRecord] = []
    private(set) var currentUserId: UUID? {
        didSet { persistSession() }
    }

    var currentUser: TravelUserRecord? {
        guard let id = currentUserId else { return nil }
        return users.first { $0.id == id }
    }

  var isSignedIn: Bool { currentUser != nil }

    private let baseURL: URL
    private let communityURL: URL
    private let mediaURL: URL
    private let sessionKey = "travel.sessionUserId"
    private let maxPhotosPerStory = 12
    private let maxJPEGBytes = 4_000_000

    init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        baseURL = support.appendingPathComponent("CapriTravel", isDirectory: true)
        communityURL = baseURL.appendingPathComponent("community.json")
        mediaURL = baseURL.appendingPathComponent("media", isDirectory: true)
        try? FileManager.default.createDirectory(at: mediaURL, withIntermediateDirectories: true)
        load()
        if let raw = UserDefaults.standard.string(forKey: sessionKey), let id = UUID(uuidString: raw),
           users.contains(where: { $0.id == id }) {
            currentUserId = id
        }
    }

    func storiesFeed() -> [TravelStoryRecord] {
        stories.sorted { $0.createdAt > $1.createdAt }
    }

    func story(id: UUID) -> TravelStoryRecord? {
        stories.first { $0.id == id }
    }

    func likeCount(for storyId: UUID) -> Int {
        storyLikes[storyId]?.count ?? 0
    }

    func commentCount(for storyId: UUID) -> Int {
        comments.filter { $0.storyId == storyId }.count
    }

    func comments(for storyId: UUID) -> [TravelCommentRecord] {
        comments.filter { $0.storyId == storyId }.sorted { $0.createdAt < $1.createdAt }
    }

    func isLiked(storyId: UUID) -> Bool {
        guard let userId = currentUserId else { return false }
        return storyLikes[storyId]?.contains(userId) == true
    }

    func toggleLike(storyId: UUID) throws {
        guard let userId = currentUserId else { throw TravelAuthError.notSignedIn }
        guard stories.contains(where: { $0.id == storyId }) else { return }
        var likes = storyLikes[storyId] ?? []
        if let idx = likes.firstIndex(of: userId) {
            likes.remove(at: idx)
        } else {
            likes.append(userId)
        }
        storyLikes[storyId] = likes.isEmpty ? nil : likes
        saveCommunity()
    }

    func addComment(storyId: UUID, text: String) throws {
        guard let user = currentUser else { throw TravelAuthError.notSignedIn }
        guard stories.contains(where: { $0.id == storyId }) else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw TravelAuthError.emptyComment }
        let capped = String(trimmed.prefix(500))
        let comment = TravelCommentRecord(
            id: UUID(),
            storyId: storyId,
            authorId: user.id,
            authorDisplayName: user.displayName,
            text: capped,
            createdAt: .now
        )
        comments.append(comment)
        saveCommunity()
    }

    func deleteComment(id: UUID) throws {
        guard let user = currentUser else { throw TravelAuthError.notSignedIn }
        guard let idx = comments.firstIndex(where: { $0.id == id }) else { return }
        guard comments[idx].authorId == user.id else { throw TravelAuthError.notYourComment }
        comments.remove(at: idx)
        saveCommunity()
    }

    func register(displayName: String, email: String, password: String) throws {
        let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let mail = Self.normalizeEmail(email)
        guard name.count >= 2 else { throw TravelAuthError.invalidDisplayName }
        guard Self.isValidEmail(mail) else { throw TravelAuthError.invalidEmail }
        guard password.count >= 6 else { throw TravelAuthError.weakPassword }
        guard !users.contains(where: { $0.email == mail }) else { throw TravelAuthError.emailTaken }

        let salt = Self.randomSalt()
        let user = TravelUserRecord(
            id: UUID(),
            displayName: name,
            email: mail,
            passwordSalt: salt,
            passwordHash: Self.hash(password: password, salt: salt),
            createdAt: .now
        )
        users.append(user)
        saveCommunity()
        currentUserId = user.id
    }

    func login(email: String, password: String) throws {
        let mail = Self.normalizeEmail(email)
        guard let user = users.first(where: { $0.email == mail }) else {
            throw TravelAuthError.invalidCredentials
        }
        let check = Self.hash(password: password, salt: user.passwordSalt)
        guard check == user.passwordHash else { throw TravelAuthError.invalidCredentials }
        currentUserId = user.id
    }

    func logout() {
        currentUserId = nil
    }

    func createStory(title: String, body: String, photoData: [Data]) throws {
        guard let user = currentUser else { throw TravelAuthError.notSignedIn }
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { throw TravelAuthError.emptyTitle }

        let storyId = UUID()
        let folder = mediaURL.appendingPathComponent(storyId.uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        var names: [String] = []
        for data in photoData.prefix(maxPhotosPerStory) {
            guard var payload = Self.jpegData(from: data) else { continue }
            if payload.count > maxJPEGBytes, let smaller = Self.jpegData(from: data, quality: 0.65) {
                payload = smaller
            }
            let name = UUID().uuidString + ".jpg"
            try payload.write(to: folder.appendingPathComponent(name), options: .atomic)
            names.append(name)
        }

        let story = TravelStoryRecord(
            id: storyId,
            authorId: user.id,
            authorDisplayName: user.displayName,
            title: t,
            body: body.trimmingCharacters(in: .whitespacesAndNewlines),
            photoNames: names,
            createdAt: .now
        )
        stories.append(story)
        saveCommunity()
    }

    func deleteStory(id: UUID) throws {
        guard let user = currentUser else { throw TravelAuthError.notSignedIn }
        guard let idx = stories.firstIndex(where: { $0.id == id }) else { return }
        guard stories[idx].authorId == user.id else { throw TravelAuthError.notYourStory }
        let folder = mediaURL.appendingPathComponent(id.uuidString, isDirectory: true)
        try? FileManager.default.removeItem(at: folder)
        stories.remove(at: idx)
        storyLikes[id] = nil
        comments.removeAll { $0.storyId == id }
        saveCommunity()
    }

    func photoURL(storyId: UUID, fileName: String) -> URL? {
        let url = mediaURL.appendingPathComponent(storyId.uuidString).appendingPathComponent(fileName)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    func shareText(for story: TravelStoryRecord, l: L10n) -> String {
        let lines = [story.title, "", story.body, "", "— \(story.authorDisplayName)", l("travel.share.footer")]
        return lines.filter { !$0.isEmpty }.joined(separator: "\n")
    }

    // MARK: - Private

    private func load() {
        try? FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true)
        guard let data = try? Data(contentsOf: communityURL),
              let file = try? JSONDecoder().decode(TravelCommunityFile.self, from: data) else { return }
        users = file.users
        stories = file.stories
        storyLikes = file.storyLikes
        comments = file.comments
    }

    private func saveCommunity() {
        let file = TravelCommunityFile(users: users, stories: stories, storyLikes: storyLikes, comments: comments)
        guard let data = try? JSONEncoder().encode(file) else { return }
        try? data.write(to: communityURL, options: .atomic)
    }

    private func persistSession() {
        if let id = currentUserId {
            UserDefaults.standard.set(id.uuidString, forKey: sessionKey)
        } else {
            UserDefaults.standard.removeObject(forKey: sessionKey)
        }
    }

    private static func normalizeEmail(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func isValidEmail(_ mail: String) -> Bool {
        mail.contains("@") && mail.contains(".") && mail.count >= 5
    }

    private static func randomSalt() -> Data {
        var bytes = [UInt8](repeating: 0, count: 16)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return Data(bytes)
    }

    private static func hash(password: String, salt: Data) -> Data {
        var payload = Data()
        payload.append(salt)
        payload.append(Data(password.utf8))
        return Data(SHA256.hash(data: payload))
    }

    private static func jpegData(from data: Data, quality: CGFloat = 0.82) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        return image.jpegData(compressionQuality: quality)
    }
}
