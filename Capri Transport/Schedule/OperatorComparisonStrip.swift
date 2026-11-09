import SwiftUI

/// Порівняння наступних рейсів кількох ліній на тому самому відрізку (cat vs hydro тощо).
struct OperatorComparisonStrip: View {
    let l: L10n
    let routes: [Route]
    let date: Date
    let nowMinutes: Int
    let selectedRouteId: String
    var onSelect: (Route) -> Void

    private var isToday: Bool { Rome.calendar.isDate(date, inSameDayAs: Rome.today) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(l("tt.compare"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(routes) { route in
                        comparisonCard(route)
                    }
                }
            }
        }
    }

    private func comparisonCard(_ route: Route) -> some View {
        let selected = route.id == selectedRouteId
        let next = nextDeparture(on: route)
        return Button { onSelect(route) } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text(serviceTitle(route))
                    .font(.caption.weight(.semibold))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                if let next {
                    Text(Rome.hhmm(next.minute))
                        .font(.title3.weight(.bold))
                        .monospacedDigit()
                    if let op = next.op {
                        Text(op).font(.caption2)
                    }
                    if isToday {
                        Text(l.until(max(0, next.minute - nowMinutes)))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text(l("sights.noService"))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(width: 132, alignment: .leading)
            .padding(12)
            .background(selected ? AppTheme.highlightFill : Color.secondary.opacity(0.08),
                        in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(selected ? AppTheme.accent : AppTheme.cardStroke, lineWidth: selected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func nextDeparture(on route: Route) -> Departure? {
        let deps = route.departures(on: date)
        if isToday {
            return deps.first(where: { $0.minute >= nowMinutes })
        }
        return deps.first
    }

    private func serviceTitle(_ route: Route) -> String {
        var parts: [String] = []
        if let k = route.kind { parts.append(l(k.rawValue)) }
        if !route.operators.isEmpty { parts.append(route.operators) }
        if parts.isEmpty { return l.name(route) }
        return parts.joined(separator: " · ")
    }
}
