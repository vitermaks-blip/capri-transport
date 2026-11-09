import Foundation

enum WidgetDepartureStore {
    static let appGroupID = "group.com.taptap.Capri-Transport"
    static let snapshotKey = "widget.nextDeparture"
}

struct WidgetDepartureSnapshot: Codable, Equatable {
    var routeTitle: String
    var time: String
    var operatorName: String?
    var pier: String?
    var minutesUntil: Int
    var updated: Date

    static func load() -> WidgetDepartureSnapshot? {
        guard let data = UserDefaults(suiteName: WidgetDepartureStore.appGroupID)?
            .data(forKey: WidgetDepartureStore.snapshotKey) else { return nil }
        return try? JSONDecoder().decode(WidgetDepartureSnapshot.self, from: data)
    }
}
