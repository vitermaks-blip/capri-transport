import SwiftUI

// MARK: - Живий заголовок

struct ScheduleLiveHeader: View {
    let l: L10n
    let now: Date
    let nowMinutes: Int
    let viewingDate: Date
    let catalogSource: TimetableDataSource
    let isRefreshing: Bool

    private var isToday: Bool { Rome.calendar.isDate(viewingDate, inSameDayAs: Rome.today) }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            if isToday {
                Circle()
                    .fill(AppTheme.accent)
                    .frame(width: 8, height: 8)
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(l(isToday ? "schedule.live" : "schedule.viewing"))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    if isRefreshing {
                        ProgressView()
                            .controlSize(.mini)
                    }
                }
                Text(Rome.hhmm(nowMinutes))
                    .font(.title2.weight(.bold))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                if !isToday {
                    Text(l.date(viewingDate, "EEEEdMMMM"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 2) {
                Text(l.nameShort(catalogSource))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                if isToday {
                    Text(l.date(Rome.today, "EEEEdMMM"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Список рейсів (оновлюється щосекунди для «сьогодні»)

struct ScheduleDeparturesList: View {
    let l: L10n
    let route: Route
    let date: Date
    let nowMinutes: Int
    let isOnline: Bool
    var onSelect: (Departure) -> Void
    var onBuyTicket: (URL) -> Void
    @Environment(\.appState) private var appState

    private var isToday: Bool { Rome.calendar.isDate(date, inSameDayAs: Rome.today) }
    private var departures: [Departure] { route.departures(on: date) }
    private var nextId: Int? {
        guard isToday else { return departures.first?.id }
        return departures.first(where: { $0.minute >= nowMinutes })?.id
    }

    var body: some View {
        if departures.isEmpty {
            ContentUnavailableView {
                Label(l("none"), systemImage: "clock.badge.questionmark")
            } description: {
                Text(l.info(route))
            }
            .frame(maxWidth: .infinity)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text(l("schedule.todayList"))
                    .font(.subheadline.weight(.semibold))
                VStack(spacing: 0) {
                    ForEach(departures) { dep in
                        let past = isToday && dep.minute < nowMinutes
                        let isNext = dep.id == nextId
                        ScheduleDepartureRow(
                            dep: dep,
                            route: route,
                            date: date,
                            l: l,
                            past: past,
                            isNext: isNext,
                            isToday: isToday,
                            nowMinutes: nowMinutes,
                            isOnline: isOnline,
                            onSelect: { onSelect(dep) },
                            onBuyTicket: onBuyTicket
                        )
                        .contextMenu { departureMenu(dep: dep) }
                        if dep.id != departures.last?.id {
                            Divider().padding(.leading, 14)
                        }
                    }
                }
                .background(.background.secondary, in: RoundedRectangle(cornerRadius: 14))
            }
        }
    }

    @ViewBuilder
    private func departureMenu(dep: Departure) -> some View {
        ShareLink(
            item: RouteShare.departureText(route: route, departure: dep, on: date, l: l),
            subject: Text(l.name(route)),
            message: Text(Rome.hhmm(dep.minute))
        ) {
            Label(l("share.departure"), systemImage: "square.and.arrow.up")
        }
        Button { onSelect(dep) } label: {
            Label(l("sights.routeMap.a11y"), systemImage: "map")
        }
        if let link = appState.deepLinkURL(routeID: route.id) {
            ShareLink(item: link, subject: Text(l.name(route))) {
                Label(l("about.deeplink.share"), systemImage: "link")
            }
        }
        if isOnline, let url = route.ticketURL(for: dep) {
            Button { onBuyTicket(url) } label: {
                Label(l("buyTicket"), systemImage: "ticket")
            }
        }
    }
}

private struct ScheduleDepartureRow: View {
    let dep: Departure
    let route: Route
    let date: Date
    let l: L10n
    let past: Bool
    let isNext: Bool
    let isToday: Bool
    let nowMinutes: Int
    let isOnline: Bool
    let onSelect: () -> Void
    let onBuyTicket: (URL) -> Void

  var body: some View {
        HStack(spacing: 10) {
            Button(action: onSelect) {
                HStack(spacing: 10) {
                    if isNext {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(AppTheme.accent)
                            .frame(width: 4)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(Rome.hhmm(dep.minute))
                                .font(.title3.monospacedDigit().weight(isNext ? .bold : .semibold))
                                .contentTransition(.numericText())
                            if let op = dep.op {
                                Text(op)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        if isNext, let pier = RoutePier.label(route: route, operator: dep.op, l: l) {
                            Text(pier)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                    Spacer(minLength: 0)
                    if isToday {
                        Text(past ? l("gone") : l.until(dep.minute - nowMinutes))
                            .font(.footnote.monospacedDigit())
                            .foregroundStyle(isNext ? AppTheme.accent : .secondary)
                            .contentTransition(.numericText())
                            .multilineTextAlignment(.trailing)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if let url = route.ticketURL(for: dep), isOnline, !past {
                Button { onBuyTicket(url) } label: {
                    MirroredSymbol(systemName: "ticket", compact: true, font: .callout)
                        .frame(width: 40, height: 40)
                        .background(isNext ? AppTheme.accent.opacity(0.2) : AppTheme.accentSoft, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(l("buyTicket"))
            }
        }
        .padding(.vertical, isNext ? 14 : 11)
        .padding(.horizontal, 14)
        .background {
            if isNext {
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppTheme.highlightFill.opacity(0.35))
                    .padding(.horizontal, 4)
            }
        }
        .opacity(past ? 0.45 : 1)
        .animation(.easeInOut(duration: 0.25), value: isNext)
    }
}

// MARK: - L10n helpers

extension L10n {
    func nameShort(_ source: TimetableDataSource) -> String {
        switch source {
        case .network: return self("data.source.network.short")
        case .cache: return self("data.source.cache.short")
        case .bundle: return self("data.source.bundle.short")
        }
    }
}
