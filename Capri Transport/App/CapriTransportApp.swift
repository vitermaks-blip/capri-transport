import SwiftUI

enum AppTab: String {
    case schedule, sights, travels
}

@main
struct CapriTransportApp: App {
    var body: some Scene {
        WindowGroup { RootView() }
    }
}

/// Вкладки: розклад і визначні місця.
struct RootView: View {
    @AppStorage("lang") private var langRaw: String = ""
    @AppStorage("app.selectedTab") private var selectedTabRaw = AppTab.schedule.rawValue
    @State private var network = NetworkMonitor()
    @State private var travel = TravelStore()
    @State private var appearance = AppAppearance()
    @State private var appState = AppState()
    private var l: L10n { L10n(lang: Lang(rawValue: langRaw) ?? .system) }
    private var selectedTab: Binding<AppTab> {
        Binding(
            get: { AppTab(rawValue: selectedTabRaw) ?? .schedule },
            set: { selectedTabRaw = $0.rawValue }
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            if !network.isOnline {
                HStack(spacing: 8) {
                    MirroredSymbol(systemName: "wifi.slash", compact: true, font: .subheadline)
                    Text(l("offline.banner"))
                        .font(.subheadline)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(AppTheme.accentSoft)
            }
            TabView(selection: selectedTab) {
                ContentView()
                    .tag(AppTab.schedule)
                    .tabItem {
                        Label {
                            Text(l("tab.schedule"))
                        } icon: {
                            MirroredSymbol(systemName: "clock", compact: true, font: .body)
                        }
                    }
                SightsView()
                    .tag(AppTab.sights)
                    .tabItem {
                        Label {
                            Text(l("tab.sights"))
                        } icon: {
                            MirroredSymbol(systemName: "photo.on.rectangle.angled", compact: true, font: .body)
                        }
                    }
                TravelsView()
                    .tag(AppTab.travels)
                    .tabItem {
                        Label {
                            Text(l("tab.travels"))
                        } icon: {
                            MirroredSymbol(systemName: "suitcase", compact: true, font: .body)
                        }
                    }
            }
            .tint(appearance.palette.accent)
        }
        .tint(appearance.palette.accent)
        .preferredColorScheme(appearance.colorScheme)
        .environment(network)
        .environment(travel)
        .environment(appearance)
        .environment(\.appState, appState)
        .onOpenURL { appState.open(url: $0) }
    }
}
