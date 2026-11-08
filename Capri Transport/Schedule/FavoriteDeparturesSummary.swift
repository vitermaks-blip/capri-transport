import SwiftUI

struct FavoriteDeparturesSummary: View {
    let l: L10n
    let nowMinutes: Int

    var body: some View {
        let rows = favoriteRows
        if !rows.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text(l("schedule.favorites.next"))
                    .font(.subheadline.weight(.semibold))
                ForEach(rows, id: \.route.id) { row in
                    HStack(alignment: .firstTextBaseline) {
                        Text(l.name(row.route))
                            .font(.footnote.weight(.medium))
                            .lineLimit(1)
                        Spacer(minLength: 8)
                        Text(row.timeLabel)
                            .font(.footnote.monospacedDigit())
                            .foregroundStyle(AppTheme.accent)
                    }
                }
            }
            .padding(12)
            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
            .accessibilityElement(children: .contain)
        }
    }

    private var favoriteRows: [Row] {
        RouteFavorites.ids.compactMap { rid in
            guard let route = TimetableQuery.route(id: rid),
                  let hit = TimetableQuery.nextService(route: route, from: Rome.today, after: nowMinutes) else {
                return nil
            }
            let day = hit.date
            let cal = Rome.calendar
            let time: String
            if cal.isDateInToday(day) {
                time = Rome.hhmm(hit.departure.minute)
            } else {
                time = "\(l.date(day, "dMMM")), \(Rome.hhmm(hit.departure.minute))"
            }
            return Row(route: route, timeLabel: time)
        }
    }

    private struct Row {
        let route: Route
        let timeLabel: String
    }
}
