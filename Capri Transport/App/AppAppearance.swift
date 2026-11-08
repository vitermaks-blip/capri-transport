import Observation
import SwiftUI

struct ThemePalette: Identifiable {
    let id: String
    let accent: Color
    let highlightFill: Color
    let highlightText: Color

    var accentSoft: Color { accent.opacity(0.22) }
    var cardStroke: Color { Color.primary.opacity(0.06) }
    var shadow: Color { Color.black.opacity(0.08) }

    static let sea = ThemePalette(
        id: "sea",
        accent: Color(red: 0.42, green: 0.52, blue: 0.55),
        highlightFill: Color(red: 0.91, green: 0.89, blue: 0.86),
        highlightText: Color(red: 0.28, green: 0.31, blue: 0.33)
    )

    static let all: [ThemePalette] = [
        .sea,
        ThemePalette(
            id: "terracotta",
            accent: Color(red: 0.72, green: 0.45, blue: 0.38),
            highlightFill: Color(red: 0.96, green: 0.91, blue: 0.88),
            highlightText: Color(red: 0.35, green: 0.26, blue: 0.22)
        ),
        ThemePalette(
            id: "olive",
            accent: Color(red: 0.48, green: 0.55, blue: 0.42),
            highlightFill: Color(red: 0.92, green: 0.93, blue: 0.89),
            highlightText: Color(red: 0.26, green: 0.30, blue: 0.24)
        ),
        ThemePalette(
            id: "dusk",
            accent: Color(red: 0.52, green: 0.48, blue: 0.62),
            highlightFill: Color(red: 0.93, green: 0.91, blue: 0.95),
            highlightText: Color(red: 0.30, green: 0.28, blue: 0.34)
        ),
        ThemePalette(
            id: "midnight",
            accent: Color(red: 0.35, green: 0.48, blue: 0.58),
            highlightFill: Color(red: 0.88, green: 0.91, blue: 0.94),
            highlightText: Color(red: 0.22, green: 0.28, blue: 0.33)
        ),
    ]

    static func named(_ id: String) -> ThemePalette {
        all.first { $0.id == id } ?? .sea
    }
}

enum ThemeColorScheme: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }

    var swiftUI: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

@Observable
final class AppAppearance {
    private static let presetKey = "theme.preset"
    private static let schemeKey = "theme.scheme"

    /// Для статичного `AppTheme` без передачі environment у кожен View.
    static var current: AppAppearance!

    var presetId: String {
        didSet {
            UserDefaults.standard.set(presetId, forKey: Self.presetKey)
        }
    }

    var scheme: ThemeColorScheme {
        didSet {
            UserDefaults.standard.set(scheme.rawValue, forKey: Self.schemeKey)
        }
    }

    var palette: ThemePalette { ThemePalette.named(presetId) }
    var colorScheme: ColorScheme? { scheme.swiftUI }

    init() {
        presetId = UserDefaults.standard.string(forKey: Self.presetKey) ?? ThemePalette.sea.id
        let raw = UserDefaults.standard.string(forKey: Self.schemeKey) ?? ThemeColorScheme.system.rawValue
        scheme = ThemeColorScheme(rawValue: raw) ?? .system
        Self.current = self
    }

    func reset() {
        presetId = ThemePalette.sea.id
        scheme = .system
    }
}

// MARK: - Налаштування

struct AppearanceSettingsView: View {
    let l: L10n
    @Environment(AppAppearance.self) private var appearance
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section(l("theme.preset")) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 148), spacing: 10)], spacing: 10) {
                        ForEach(ThemePalette.all) { preset in
                            Button {
                                appearance.presetId = preset.id
                            } label: {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Circle()
                                            .fill(preset.accent)
                                            .frame(width: 28, height: 28)
                                        Spacer()
                                        if preset.id == appearance.presetId {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundStyle(preset.accent)
                                        }
                                    }
                                    Text(l("theme.preset.\(preset.id)"))
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(.primary)
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(preset.highlightFill)
                                        .frame(height: 22)
                                        .overlay {
                                            Text("Aa")
                                                .font(.caption2.weight(.semibold))
                                                .foregroundStyle(preset.highlightText)
                                        }
                                }
                                .padding(12)
                                .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(
                                            preset.id == appearance.presetId ? preset.accent : Color.clear,
                                            lineWidth: 2
                                        )
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section(l("theme.scheme")) {
                    Picker(l("theme.scheme"), selection: Bindable(appearance).scheme) {
                        ForEach(ThemeColorScheme.allCases) { mode in
                            Text(l("theme.scheme.\(mode.rawValue)")).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    Button(l("theme.reset")) {
                        appearance.reset()
                    }
                }

                Section {
                    Text(l("theme.note"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section {
                    NavigationLink {
                        AboutDataView(l: l)
                    } label: {
                        Text(l("about.title"))
                    }
                }
            }
            .navigationTitle(l("theme.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(l("close")) { dismiss() }
                }
            }
        }
    }
}
