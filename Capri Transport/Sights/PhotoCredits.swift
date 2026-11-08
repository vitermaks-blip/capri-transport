import Foundation

struct PhotoCredit: Identifiable, Decodable {
    let sightId: String
    let commonsTitle: String
    let license: String
    let artist: String
    let page: String
    let shareAlike: Bool
    let verified: Bool
    let note: String?

    var id: String { sightId }
    var pageURL: URL? { SafeURL.https(page) }
}

enum PhotoCreditsCatalog {
    static let all: [PhotoCredit] = load()

    private static func load() -> [PhotoCredit] {
        guard let url = Bundle.main.url(forResource: "photo-credits", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let file = try? JSONDecoder().decode(PhotoCreditsFile.self, from: data) else {
            assertionFailure("photo-credits.json не знайдено")
            return []
        }
        return file.photos
    }

    static func credit(for sightId: String) -> PhotoCredit? {
        all.first { $0.sightId == sightId }
    }
}

private struct PhotoCreditsFile: Decodable {
    let photos: [PhotoCredit]
}
