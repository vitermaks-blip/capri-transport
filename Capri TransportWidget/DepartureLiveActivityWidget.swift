import ActivityKit
import SwiftUI
import WidgetKit

@available(iOS 16.2, *)
struct DepartureLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DepartureActivityAttributes.self) { context in
            VStack(alignment: .leading, spacing: 4) {
                Text(context.attributes.routeTitle)
                    .font(.caption)
                Text(context.state.timeLabel)
                    .font(.title2.bold())
                    .monospacedDigit()
                if context.state.minutesUntil > 0 {
                    Text("in \(context.state.minutesUntil) min")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                if let pier = context.attributes.pier {
                    Text(pier).font(.caption2).lineLimit(1)
                }
            }
            .padding(12)
            .activityBackgroundTint(.black.opacity(0.65))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(context.state.timeLabel)
                        .font(.title3.bold())
                        .monospacedDigit()
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if context.state.minutesUntil > 0 {
                        Text("\(context.state.minutesUntil)m")
                            .font(.caption.monospacedDigit())
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.attributes.routeTitle)
                        .font(.caption)
                        .lineLimit(1)
                }
            } compactLeading: {
                Text(context.state.timeLabel)
                    .font(.caption.bold())
                    .monospacedDigit()
            } compactTrailing: {
                Text("\(max(0, context.state.minutesUntil))m")
                    .font(.caption2.monospacedDigit())
            } minimal: {
                Text(context.state.timeLabel)
                    .font(.caption2.monospacedDigit())
            }
        }
    }
}
