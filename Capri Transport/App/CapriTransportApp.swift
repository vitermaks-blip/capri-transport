import CoreSpotlight
import SwiftUI

enum AppTab: String {
    case schedule, sights
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
    @State private var appearance = AppAppearance()
    @State private var appState = AppState()
    @State private var catalog = TimetableCatalogStore.shared
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
            } else {
                DataDisclaimerBanner(l: l, source: catalog.source, style: .strip)
            }
            if let days = CatalogFreshness.daysSinceUpdate(catalog.dataUpdated),
               CatalogFreshness.isStale(catalog.dataUpdated) {
                StaleCatalogBanner(l: l, daysOld: days)
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
            }
            .tint(appearance.palette.accent)
        }
        .tint(appearance.palette.accent)
        .preferredColorScheme(appearance.colorScheme)
        .environment(network)
        .environment(catalog)
        .environment(appearance)
        .environment(\.appState, appState)
        .task {
            SpotlightIndexer.reindex()
            await catalog.refreshFromNetworkIfNeeded(isOnline: network.isOnline)
        }
        .onChange(of: catalog.dataUpdated) { _, _ in
            SpotlightIndexer.reindex()
        }
        .onChange(of: network.isOnline) { _, online in
            guard online else { return }
            Task { await catalog.refreshFromNetworkIfNeeded(isOnline: true) }
        }
        .onOpenURL { appState.open(url: $0) }
        .onContinueUserActivity(CSSearchableItemActionType) { activity in
            guard let raw = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String else { return }
            if raw.hasPrefix("route:") {
                let id = String(raw.dropFirst("route:".count))
                appState.show(routeID: id)
            } else if raw.hasPrefix("sight:") {
                let id = String(raw.dropFirst("sight:".count))
                appState.show(sightID: id)
            }
        }
    }
}
