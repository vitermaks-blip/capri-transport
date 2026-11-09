import ActivityKit
import Foundation

@available(iOS 16.2, *)
enum DepartureLiveActivityManager {
    static func sync(nowMinutes: Int, l: L10n, preferredRouteId: String?) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        guard let hit = FavoriteWidgetWriter.nextHit(nowMinutes: nowMinutes, preferredRouteId: preferredRouteId),
              RouteFavorites.contains(hit.route.id) else {
            endAll()
            return
        }

        let state = DepartureActivityAttributes.ContentState(
            timeLabel: Rome.hhmm(hit.departure.minute),
            minutesUntil: max(0, hit.departure.minute - nowMinutes)
        )
        let attrs = DepartureActivityAttributes(
            routeTitle: l.name(hit.route),
            operatorName: hit.departure.op,
            pier: RoutePier.label(route: hit.route, operator: hit.departure.op, l: l)
        )

        let stale = Calendar.current.date(byAdding: .minute, value: max(1, state.minutesUntil + 5), to: .now)

        if let activity = Activity<DepartureActivityAttributes>.activities.first {
            Task {
                await activity.update(ActivityContent(state: state, staleDate: stale))
            }
        } else {
            Task {
                _ = try? Activity.request(
                    attributes: attrs,
                    content: ActivityContent(state: state, staleDate: stale),
                    pushType: nil
                )
            }
        }
    }

    static func endAll() {
        for activity in Activity<DepartureActivityAttributes>.activities {
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
        }
    }
}
