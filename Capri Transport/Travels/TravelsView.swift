import PhotosUI
import SwiftUI

// MARK: - Вкладка «Подорожі»

struct TravelsView: View {
    @Environment(TravelStore.self) private var travel
    @AppStorage("lang") private var langRaw: String = ""
    @State private var authMode: AuthSheetMode?
    @State private var composeStory = false
    @State private var showAppearance = false

    private var lang: Lang { Lang(rawValue: langRaw) ?? .system }
    private var l: L10n { L10n(lang: lang) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    feedSection
                    if !travel.isSignedIn {
                        guestAuthSection
                    }
                }
                .readableContentWidth()
                .padding(.vertical, 12)
            }
            .navigationTitle(l("travel.title"))
            .dynamicTypeSize(...DynamicTypeSize.accessibility3)
            .toolbar { toolbarContent }
            .sheet(item: $authMode) { mode in
                TravelAuthSheet(mode: mode) { authMode = nil }
            }
            .sheet(isPresented: $composeStory) {
                TravelStoryEditor { composeStory = false }
            }
            .sheet(isPresented: $showAppearance) {
                AppearanceSettingsView(l: l)
            }
        }
    }

    @ViewBuilder
    private var feedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(l("travel.feed.title"))
                .font(.title2.weight(.semibold))
            Text(l("travel.feed.subtitle"))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            let feed = travel.storiesFeed()
            if feed.isEmpty {
                ContentUnavailableView {
                    Label(l("travel.empty.title"), systemImage: "suitcase")
                } description: {
                    Text(l("travel.empty.hint"))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                ForEach(feed) { story in
                    TravelFeedCard(storyId: story.id) {
                        authMode = .signIn
                    }
                }
            }
        }
    }

    private var guestAuthSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Divider()
            Text(l("travel.guest.intro"))
                .font(.body)
                .foregroundStyle(.secondary)
            Button {
                authMode = .register
            } label: {
                Text(l("travel.register"))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.accent)

            Button(l("travel.signIn")) {
                authMode = .signIn
            }
            .frame(maxWidth: .infinity)

            Text(l("travel.guest.note"))
                .font(.footnote)
                .foregroundStyle(.tertiary)
            Text(l("travel.privacy.keychain"))
                .font(.footnote)
                .foregroundStyle(.tertiary)
        }
        .padding(.top, 8)
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button { showAppearance = true } label: {
                Image(systemName: "paintpalette")
                    .symbolRenderingMode(.hierarchical)
            }
            .accessibilityLabel(l("theme.title"))
        }
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                ForEach(Lang.allCases) { lg in
                    Button(lg.rawValue.uppercased()) { langRaw = lg.rawValue }
                }
            } label: { Label(lang.rawValue.uppercased(), systemImage: "globe") }
        }
        if travel.isSignedIn {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    composeStory = true
                } label: {
                    MirroredSymbol(systemName: "plus", compact: true, font: .body)
                }
                .accessibilityLabel(l("travel.new"))
            }
            ToolbarItem(placement: .topBarLeading) {
                Menu {
                    if let user = travel.currentUser {
                        Text(user.displayName)
                    }
                    Button(role: .destructive) {
                        travel.logout()
                    } label: {
                        Text(l("travel.signOut"))
                    }
                    Text(l("travel.privacy.signedIn"))
                        .font(.caption)
                } label: {
                    MirroredSymbol(systemName: "person.circle", compact: true, font: .body)
                }
            }
        }
    }
}

// MARK: - Картка стрічки

private struct TravelFeedCard: View {
    let storyId: UUID
    var onRequireSignIn: () -> Void

    @Environment(TravelStore.self) private var travel
    @AppStorage("lang") private var langRaw: String = ""
    private var l: L10n { L10n(lang: Lang(rawValue: langRaw) ?? .system) }

    private var story: TravelStoryRecord? { travel.story(id: storyId) }

    var body: some View {
        if let story {
            VStack(alignment: .leading, spacing: 12) {
                NavigationLink {
                    TravelStoryDetail(storyId: storyId, onRequireSignIn: onRequireSignIn)
                } label: {
                    VStack(alignment: .leading, spacing: 10) {
                        if let name = story.photoNames.first,
                           let url = travel.photoURL(storyId: story.id, fileName: name) {
                            TravelPhoto(url: url)
                                .frame(height: 180)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        Text(story.title)
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)
                        HStack {
                            Text(story.authorDisplayName)
                            Spacer()
                            Text(l.date(story.createdAt, "d MMM y"))
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        if !story.body.isEmpty {
                            Text(story.body)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(3)
                                .multilineTextAlignment(.leading)
                        }
                    }
                }
                .buttonStyle(.plain)

                TravelStoryEngagementBar(storyId: storyId, onRequireSignIn: onRequireSignIn)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemGroupedBackground)))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.cardStroke, lineWidth: 1))
        }
    }
}

// MARK: - Лайки / коментарі (стрічка)

private struct TravelStoryEngagementBar: View {
    let storyId: UUID
    var onRequireSignIn: () -> Void

    @Environment(TravelStore.self) private var travel
    @AppStorage("lang") private var langRaw: String = ""
    private var l: L10n { L10n(lang: Lang(rawValue: langRaw) ?? .system) }

    private var liked: Bool { travel.isLiked(storyId: storyId) }
    private var likeCount: Int { travel.likeCount(for: storyId) }
    private var commentCount: Int { travel.commentCount(for: storyId) }

    var body: some View {
        HStack(spacing: 16) {
            Button {
                if travel.isSignedIn {
                    try? travel.toggleLike(storyId: storyId)
                } else {
                    onRequireSignIn()
                }
            } label: {
                Label {
                    Text(likeCount > 0 ? "\(likeCount)" : l("travel.like"))
                } icon: {
                    Image(systemName: liked ? "heart.fill" : "heart")
                }
                .labelStyle(.titleAndIcon)
            }
            .buttonStyle(.borderless)
            .tint(liked ? .pink : AppTheme.accent)
            .accessibilityLabel(l("travel.like"))

            NavigationLink {
                TravelStoryDetail(storyId: storyId, onRequireSignIn: onRequireSignIn)
            } label: {
                Label {
                    Text(commentCount > 0 ? "\(commentCount)" : l("travel.comments"))
                } icon: {
                    Image(systemName: "bubble.right")
                }
                .labelStyle(.titleAndIcon)
            }
            .buttonStyle(.borderless)
            .tint(AppTheme.accent)

            Spacer()
        }
        .font(.subheadline.weight(.medium))
    }
}

// MARK: - Деталі

struct TravelStoryDetail: View {
    let storyId: UUID
    var onRequireSignIn: () -> Void = {}

    @Environment(TravelStore.self) private var travel
    @Environment(\.dismiss) private var dismiss
    @AppStorage("lang") private var langRaw: String = ""
    @State private var confirmDelete = false
    @State private var commentDraft = ""
    @State private var commentError: String?

    private var l: L10n { L10n(lang: Lang(rawValue: langRaw) ?? .system) }
    private var story: TravelStoryRecord? { travel.story(id: storyId) }
    private var isOwner: Bool { travel.currentUser?.id == story?.authorId }

    var body: some View {
        Group {
            if story == nil {
                ContentUnavailableView(l("travel.story.missing"), systemImage: "exclamationmark.triangle")
            } else {
                storyContent
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isOwner, story != nil {
                ToolbarItem(placement: .destructiveAction) {
                    Button(role: .destructive) {
                        confirmDelete = true
                    } label: {
                        Text(l("travel.delete"))
                    }
                }
            }
        }
        .confirmationDialog(l("travel.delete"), isPresented: $confirmDelete, titleVisibility: .visible) {
            Button(l("travel.delete.confirm"), role: .destructive) {
                try? travel.deleteStory(id: storyId)
                dismiss()
            }
        }
    }

    private var storyContent: some View {
        ScrollView {
            if let story {
                VStack(alignment: .leading, spacing: 16) {
                    if !story.photoNames.isEmpty {
                        TabView {
                            ForEach(story.photoNames, id: \.self) { name in
                                if let url = travel.photoURL(storyId: story.id, fileName: name) {
                                    TravelPhoto(url: url)
                                }
                            }
                        }
                        .tabViewStyle(.page(indexDisplayMode: .automatic))
                        .frame(height: 260)
                    }

                    Text(story.title)
                        .font(.title2.weight(.semibold))

                    Label(story.authorDisplayName, systemImage: "person.fill")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if !story.body.isEmpty {
                        Text(story.body)
                            .font(.body)
                    }

                    TravelStoryEngagementBar(storyId: storyId, onRequireSignIn: onRequireSignIn)

                    commentsSection(storyId: storyId)

                    ShareLink(item: travel.shareText(for: story, l: l)) {
                        Label(l("travel.share"), systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(AppTheme.accent)
                }
                .padding(20)
            }
        }
    }

    @ViewBuilder
    private func commentsSection(storyId: UUID) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(l("travel.comments"))
                .font(.headline)

            let items = travel.comments(for: storyId)
            if items.isEmpty {
                Text(l("travel.comment.empty"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(items) { comment in
                    TravelCommentRow(comment: comment)
                }
            }

            if travel.isSignedIn {
                HStack(alignment: .top, spacing: 8) {
                    TextField(l("travel.comment.placeholder"), text: $commentDraft, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(1...4)
                    Button(l("travel.comment.post")) { postComment() }
                        .disabled(commentDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                if let commentError {
                    Text(commentError)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            } else {
                Button(l("travel.comment.signIn")) { onRequireSignIn() }
                    .font(.subheadline)
            }
        }
        .padding(.top, 8)
    }

    private func postComment() {
        commentError = nil
        do {
            try travel.addComment(storyId: storyId, text: commentDraft)
            commentDraft = ""
        } catch TravelAuthError.emptyComment {
            commentError = l("travel.error.emptyComment")
        } catch {
            commentError = l("travel.error.generic")
        }
    }
}

private struct TravelCommentRow: View {
    let comment: TravelCommentRecord
    @Environment(TravelStore.self) private var travel
    @AppStorage("lang") private var langRaw: String = ""
    private var l: L10n { L10n(lang: Lang(rawValue: langRaw) ?? .system) }

    private var isOwner: Bool { travel.currentUser?.id == comment.authorId }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(comment.authorDisplayName)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(l.date(comment.createdAt, "d MMM HH:mm"))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                if isOwner {
                    Button(role: .destructive) {
                        try? travel.deleteComment(id: comment.id)
                    } label: {
                        Image(systemName: "trash")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                }
            }
            Text(comment.text)
                .font(.subheadline)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(AppTheme.highlightFill.opacity(0.6)))
    }
}

// MARK: - Редактор

struct TravelStoryEditor: View {
    @Environment(TravelStore.self) private var travel
    @Environment(\.dismiss) private var dismiss
    @AppStorage("lang") private var langRaw: String = ""
    @State private var title = ""
    @State private var bodyText = ""
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var photoData: [Data] = []
    @State private var saving = false
    @State private var errorMessage: String?

    private var l: L10n { L10n(lang: Lang(rawValue: langRaw) ?? .system) }

    var onDone: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section(l("travel.field.title")) {
                    TextField(l("travel.field.title.placeholder"), text: $title)
                }
                Section(l("travel.field.body")) {
                    TextEditor(text: $bodyText)
                        .frame(minHeight: 120)
                }
                Section {
                    PhotosPicker(selection: $pickerItems, maxSelectionCount: 12, matching: .images) {
                        Label(l("travel.field.photos"), systemImage: "photo.on.rectangle.angled")
                    }
                    if !photoData.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(Array(photoData.enumerated()), id: \.offset) { _, data in
                                    if let ui = UIImage(data: data) {
                                        Image(uiImage: ui)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 72, height: 72)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                    }
                                }
                            }
                        }
                    }
                }
                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.footnote)
                    }
                }
            }
            .navigationTitle(l("travel.new"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(l("close")) { dismiss(); onDone() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(l("travel.publish")) { publish() }
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || saving)
                }
            }
            .onChange(of: pickerItems) { _, items in
                Task { await loadPhotos(from: items) }
            }
        }
    }

    private func publish() {
        saving = true
        do {
            try travel.createStory(title: title, body: bodyText, photoData: photoData)
            dismiss()
            onDone()
        } catch TravelAuthError.emptyTitle {
            errorMessage = l("travel.error.emptyTitle")
            saving = false
        } catch {
            errorMessage = l("travel.error.generic")
            saving = false
        }
    }

    private func loadPhotos(from items: [PhotosPickerItem]) async {
        var loaded: [Data] = []
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self) {
                loaded.append(data)
            }
        }
        await MainActor.run { photoData = loaded }
    }
}

// MARK: - Авторизація

enum AuthSheetMode: String, Identifiable {
    case register, signIn
    var id: String { rawValue }
}

struct TravelAuthSheet: View {
    let mode: AuthSheetMode
    var onDismiss: () -> Void

    @Environment(TravelStore.self) private var travel
    @Environment(\.dismiss) private var dismiss
    @AppStorage("lang") private var langRaw: String = ""
    @State private var displayName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage: String?

    private var l: L10n { L10n(lang: Lang(rawValue: langRaw) ?? .system) }
    private var isRegister: Bool { mode == .register }

    var body: some View {
        NavigationStack {
            Form {
                if isRegister {
                    Section(l("travel.field.name")) {
                        TextField(l("travel.field.name.placeholder"), text: $displayName)
                            .textContentType(.name)
                            .autocorrectionDisabled()
                    }
                }
                Section(l("travel.field.email")) {
                    TextField("email@example.com", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                Section(l("travel.field.password")) {
                    SecureField(l("travel.field.password.placeholder"), text: $password)
                        .textContentType(isRegister ? .newPassword : .password)
                }
                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(.red).font(.footnote)
                    }
                }
                Section {
                    Text(l("travel.auth.note"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle(isRegister ? l("travel.register") : l("travel.signIn"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(l("close")) { dismiss(); onDismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isRegister ? l("travel.register") : l("travel.signIn")) { submit() }
                }
            }
        }
    }

    private func submit() {
        errorMessage = nil
        do {
            if isRegister {
                try travel.register(displayName: displayName, email: email, password: password)
            } else {
                try travel.login(email: email, password: password)
            }
            dismiss()
            onDismiss()
        } catch let err as TravelAuthError {
            errorMessage = message(for: err)
        } catch {
            errorMessage = l("travel.error.generic")
        }
    }

    private func message(for error: TravelAuthError) -> String {
        switch error {
        case .emailTaken: return l("travel.error.emailTaken")
        case .invalidCredentials: return l("travel.error.credentials")
        case .weakPassword: return l("travel.error.weakPassword")
        case .invalidDisplayName: return l("travel.error.name")
        case .invalidEmail: return l("travel.error.email")
        case .emptyComment: return l("travel.error.emptyComment")
        case .emptyTitle: return l("travel.error.emptyTitle")
        default: return l("travel.error.generic")
        }
    }
}

// MARK: - Зображення з диска

private struct TravelPhoto: View {
    let url: URL
    var body: some View {
        Group {
            if let ui = UIImage(contentsOfFile: url.path) {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFill()
            } else {
                Color.gray.opacity(0.2)
            }
        }
        .clipped()
    }
}
