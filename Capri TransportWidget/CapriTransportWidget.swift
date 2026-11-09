import SwiftUI
import WidgetKit

struct CapriDepartureEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetDepartureSnapshot?
}

struct CapriDepartureProvider: TimelineProvider {
    func placeholder(in context: Context) -> CapriDepartureEntry {
        CapriDepartureEntry(date: .now, snapshot: WidgetDepartureSnapshot(
            routeTitle: "Naples → Capri",
            time: "09:30",
            operatorName: "SNAV",
            pier: "Molo Beverello",
            minutesUntil: 25,
            updated: .now
        ))
    }

    func getSnapshot(in context: Context, completion: @escaping (CapriDepartureEntry) -> Void) {
        completion(CapriDepartureEntry(date: .now, snapshot: WidgetDepartureSnapshot.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CapriDepartureEntry>) -> Void) {
        let entry = CapriDepartureEntry(date: .now, snapshot: WidgetDepartureSnapshot.load())
        let next = Calendar.current.date(byAdding: .minute, value: 15, to: .now) ?? .now.addingTimeInterval(900)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

struct CapriDepartureWidgetView: View {
    var entry: CapriDepartureEntry

    var body: some View {
        if let s = entry.snapshot {
            VStack(alignment: .leading, spacing: 4) {
                Text(s.routeTitle)
                    .font(.caption)
                    .lineLimit(1)
                Text(s.time)
                    .font(.title.bold())
                    .monospacedDigit()
                if let pier = s.pier {
                    Text(pier).font(.caption2).lineLimit(2)
                }
                if s.minutesUntil > 0 {
                    Text("in \(s.minutesUntil) min")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        } else {
            VStack(alignment: .leading, spacing: 4) {
                Text("Capri Transport")
                    .font(.caption.weight(.semibold))
                Text("Star a route in the app")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }
}

@main
struct CapriTransportWidgetBundle: WidgetBundle {
    var body: some Widget {
        CapriDepartureWidget()
        if #available(iOS 16.2, *) {
            DepartureLiveActivityWidget()
        }
    }
}

struct CapriDepartureWidget: Widget {
    let kind = "CapriDepartureWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CapriDepartureProvider()) { entry in
            CapriDepartureWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Next departure")
        .description("Next favorite ferry or bus from Capri Transport.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
