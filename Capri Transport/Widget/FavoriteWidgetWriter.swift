import Foundation

/// Знімок для домашнього віджета та Live Activity (App Group).
enum FavoriteWidgetWriter {
    static func update(nowMinutes: Int, l: L10n, preferredRouteId: String?) {
        guard let defaults = UserDefaults(suiteName: WidgetDepartureStore.appGroupID) else { return }
        guard let hit = nextHit(nowMinutes: nowMinutes, preferredRouteId: preferredRouteId) else {
            defaults.removeObject(forKey: WidgetDepartureStore.snapshotKey)
            return
        }
        let snap = WidgetDepartureSnapshot(
            routeTitle: l.name(hit.route),
            time: Rome.hhmm(hit.departure.minute),
            operatorName: hit.departure.op,
            pier: RoutePier.label(route: hit.route, operator: hit.departure.op, l: l),
            minutesUntil: max(0, hit.departure.minute - nowMinutes),
            updated: .now
        )
        if let data = try? JSONEncoder().encode(snap) {
            defaults.set(data, forKey: WidgetDepartureStore.snapshotKey)
        }
    }

    static func loadSnapshot() -> WidgetDepartureSnapshot? {
        WidgetDepartureSnapshot.load()
    }

    static func nextHit(nowMinutes: Int, preferredRouteId: String?) -> (route: Route, departure: Departure)? {
        let ids: [String] = {
            if let preferredRouteId {
                return [preferredRouteId] + RouteFavorites.ids.filter { $0 != preferredRouteId }
            }
            return RouteFavorites.ids
        }()
        for rid in ids {
            guard let route = TimetableQuery.route(id: rid),
                  let hit = TimetableQuery.nextService(route: route, from: Rome.today, after: nowMinutes),
                  Rome.calendar.isDateInToday(hit.date) else { continue }
            return (route, hit.departure)
        }
        return nil
    }
}
