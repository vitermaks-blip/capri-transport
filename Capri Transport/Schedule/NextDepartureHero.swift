import SwiftUI

/// Найближчий рейс (обраний маршрут або перший у списку обраних) — «віджет у застосунку».
struct NextDepartureHero: View {
    let l: L10n
    let nowMinutes: Int
    var preferredRouteId: String?
    var onOpen: (Route, Departure) -> Void

    var body: some View {
        if let hit = nextHit {
            let cal = Rome.calendar
            let dayNote = cal.isDate(hit.serviceDate, inSameDayAs: Rome.today)
                ? nil as String?
                : l.date(hit.serviceDate, "EEEEdMMM")
            DepartureHighlightCard(
                l: l,
                route: hit.route,
                departure: hit.departure,
                captionKey: hit.captionKey,
                dayNote: dayNote,
                untilMinutes: hit.untilMinutes(nowMinutes: nowMinutes),
                onOpen: onOpen
            )
        }
    }

    private var nextHit: DepartureHeroHit? {
        let cal = Rome.calendar
        let today = Rome.today
        let candidateIds: [String] = {
            if let preferredRouteId, RouteFavorites.contains(preferredRouteId) {
                return [preferredRouteId]
            }
            if let preferredRouteId {
                return [preferredRouteId] + RouteFavorites.ids.filter { $0 != preferredRouteId }
            }
            return RouteFavorites.ids
        }()

        for rid in candidateIds {
            guard let route = TimetableQuery.route(id: rid),
                  let hit = TimetableQuery.nextService(route: route, from: today, after: nowMinutes),
                  cal.isDateInToday(hit.date) else { continue }
            return DepartureHeroHit(
                route: route,
                departure: hit.departure,
                serviceDate: hit.date,
                captionKey: "hero.next"
            )
        }

        if let preferredRouteId, let route = TimetableQuery.route(id: preferredRouteId),
           let dep = route.departures(on: today).first(where: { $0.minute >= nowMinutes }) {
            return DepartureHeroHit(route: route, departure: dep, serviceDate: today, captionKey: "hero.next")
        }

        if let preferredRouteId, let route = TimetableQuery.route(id: preferredRouteId),
           let hit = TimetableQuery.nextService(route: route, from: today, after: nowMinutes) {
            let key = cal.isDateInToday(hit.date) ? "hero.next" : "hero.later"
            return DepartureHeroHit(route: route, departure: hit.departure, serviceDate: hit.date, captionKey: key)
        }

        return nil
    }
}

/// Компактний герой для обраного дня / маршруту (не «сьогодні» у шапці).
struct RouteDayDepartureHero: View {
    let l: L10n
    let route: Route
    let date: Date
    let nowMinutes: Int
    var onOpen: (Route, Departure) -> Void

    var body: some View {
        if let dep = highlightDeparture {
            DepartureHighlightCard(
                l: l,
                route: route,
                departure: dep,
                captionKey: "hero.onDay",
                dayNote: l.date(date, "EEEEdMMMM"),
                untilMinutes: Rome.minutesUntil(day: date, departureMinute: dep.minute),
                onOpen: onOpen
            )
        }
    }

    private var highlightDeparture: Departure? {
        let deps = route.departures(on: date)
        guard !deps.isEmpty else { return nil }
        let cal = Rome.calendar
        if cal.isDate(date, inSameDayAs: Rome.today) {
            return deps.first(where: { $0.minute >= nowMinutes }) ?? deps.first
        }
        return deps.first
    }
}

// MARK: - Спільна картка

private struct DepartureHeroHit {
    let route: Route
    let departure: Departure
    let serviceDate: Date
    let captionKey: String

    func untilMinutes(nowMinutes: Int) -> Int? {
        let cal = Rome.calendar
        if cal.isDate(serviceDate, inSameDayAs: Rome.today) {
            let delta = departure.minute - nowMinutes
            return delta >= 0 ? delta : nil
        }
        return Rome.minutesUntil(day: serviceDate, departureMinute: departure.minute)
    }
}

private struct DepartureHighlightCard: View {
    let l: L10n
    let route: Route
    let departure: Departure
    let captionKey: String
    var dayNote: String?
    var untilMinutes: Int?
    var onOpen: (Route, Departure) -> Void

    var body: some View {
        Button {
            onOpen(route, departure)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                Text(l(captionKey))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.highlightText.opacity(0.85))
                if let dayNote {
                    Text(dayNote)
                        .font(.caption2)
                        .foregroundStyle(AppTheme.highlightText.opacity(0.75))
                }
                Text(Rome.hhmm(departure.minute))
                    .font(.system(size: 44, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(AppTheme.highlightText)
                Text(l.name(route))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppTheme.highlightText)
                HStack(spacing: 8) {
                    if let op = departure.op {
                        Text(op).font(.footnote.weight(.semibold))
                    }
                    if let pier = RoutePier.label(route: route, operator: departure.op, l: l) {
                        Text(pier).font(.footnote).lineLimit(2)
                    }
                    Spacer(minLength: 0)
                    if let untilMinutes {
                        Text(l.until(untilMinutes))
                            .font(.footnote.monospacedDigit())
                            .contentTransition(.numericText())
                    }
                }
                .foregroundStyle(AppTheme.highlightText.opacity(0.9))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(AppTheme.highlightFill, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(AppTheme.cardStroke))
        }
        .buttonStyle(.plain)
        .accessibilityHint(l("tip"))
    }
}
