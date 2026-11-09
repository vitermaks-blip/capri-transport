import ActivityKit
import Foundation

struct DepartureActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var timeLabel: String
        var minutesUntil: Int
    }

    var routeTitle: String
    var operatorName: String?
    var pier: String?
}
