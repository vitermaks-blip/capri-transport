import Foundation
import SwiftUI

/// Глибокі посилання та синхронізація вкладки розкладу з UserDefaults.
final class AppState {
    enum Tab: String {
        case timetable = "schedule"
        case sights
        case travels
    }

    private let defaults: UserDefaults

    private enum Key {
        static let tab = "app.selectedTab"
        static let mode = "timetable.mode"
        static let routeID = "timetable.routeId"
        static let from = "timetable.from"
        static let to = "timetable.to"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var tab: Tab {
        get { Tab(rawValue: defaults.string(forKey: Key.tab) ?? "") ?? .timetable }
        set { defaults.set(newValue.rawValue, forKey: Key.tab) }
    }

    var mode: Mode {
        get { Mode(rawValue: defaults.string(forKey: Key.mode) ?? "") ?? .ships }
        set { defaults.set(newValue.rawValue, forKey: Key.mode) }
    }

    var routeID: String {
        get { defaults.string(forKey: Key.routeID) ?? "" }
        set { defaults.set(newValue, forKey: Key.routeID) }
    }

    func show(routeID: String) {
        guard let route = Catalog.all.first(where: { $0.id == routeID }) else { return }
        tab = .timetable
        mode = route.mode
        self.routeID = routeID
        defaults.set(route.from.rawValue, forKey: Key.from)
        defaults.set(route.to.rawValue, forKey: Key.to)
    }

    func show(tab: Tab) {
        self.tab = tab
    }

    /// `capritransport://route/bus-mg-ana` або `capritransport://tab/sights`
    @discardableResult
    func open(url: URL) -> Bool {
        guard url.scheme?.lowercased() == "capritransport" else { return false }
        let pathID = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        switch url.host?.lowercased() {
        case "route":
            guard !pathID.isEmpty, Catalog.all.contains(where: { $0.id == pathID }) else { return false }
            show(routeID: pathID)
            return true
        case "tab":
            guard let tab = Tab(rawValue: pathID.isEmpty ? (url.query ?? "") : pathID) else { return false }
            show(tab: tab)
            return true
        default:
            return false
        }
    }

    func deepLinkURL(routeID: String) -> URL? {
        URL(string: "capritransport://route/\(routeID)")
    }
}

private struct AppStateKey: EnvironmentKey {
    static let defaultValue = AppState()
}

extension EnvironmentValues {
    var appState: AppState {
        get { self[AppStateKey.self] }
        set { self[AppStateKey.self] = newValue }
    }
}
