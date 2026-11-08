import Foundation

enum RouteFavorites {
    private static let key = "timetable.favoriteRouteIds"
    static var defaults: UserDefaults = .standard

    static var ids: [String] {
        (defaults.string(forKey: key) ?? "")
            .split(separator: ",")
            .map { String($0) }
            .filter { !$0.isEmpty }
    }

    static func contains(_ routeID: String) -> Bool {
        ids.contains(routeID)
    }

    static func toggle(_ routeID: String) {
        var set = Set(ids)
        if set.contains(routeID) {
            set.remove(routeID)
        } else {
            set.insert(routeID)
        }
        let sorted = set.sorted()
        defaults.set(sorted.joined(separator: ","), forKey: key)
    }
}
