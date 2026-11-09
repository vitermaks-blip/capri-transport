import SwiftUI
import UIKit

struct Selection: Identifiable {
    let route: Route
    let departure: Departure
    var id: String { route.id + "-\(departure.minute)" }
}

struct ContentView: View {
    @AppStorage("lang") private var langRaw: String = ""
    @AppStorage("timetable.mode") private var modeRaw = Mode.ships.rawValue
    @AppStorage("timetable.routeId") private var storedRouteId = ""
    @AppStorage("timetable.from") private var fromRaw = ""
    @AppStorage("timetable.to") private var toRaw = ""
    @State private var date = Rome.today
    @State private var selection: Selection?
    @State private var showAppearance = false
    @State private var showAbout = false
    @State private var favoritesRevision = 0
    @State private var ticketSafariURL: URL?
    @State private var lastNextDepartureId: Int?
    @Environment(NetworkMonitor.self) private var network
    @State private var catalog = TimetableCatalogStore.shared
    @Environment(\.appState) private var appState
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var lang: Lang { Lang(rawValue: langRaw) ?? .system }
    private var l: L10n { L10n(lang: lang) }
    private var mode: Mode { Mode(rawValue: modeRaw) ?? .ships }
    private var modeSelection: Binding<Mode> {
        Binding(
            get: { Mode(rawValue: modeRaw) ?? .ships },
            set: { modeRaw = $0.rawValue; syncStoredRoute() }
        )
    }
    private var routes: [Route] { catalog.routes.filter { $0.mode == mode } }
    private var matchingRoutes: [Route] {
        routes.filter { $0.from == from && $0.to == to }
    }
    private var route: Route {
        let fallback = routes.first ?? catalog.routes.first ?? Route(
            id: "empty", mode: .ships, from: .mg, to: .capri
        )
        if let r = matchingRoutes.first(where: { $0.id == storedRouteId }) { return r }
        if let r = matchingRoutes.first { return r }
        if let r = routes.first(where: { $0.id == storedRouteId }) { return r }
        return fallback
    }
    private var from: PlaceID {
        if let p = PlaceID(rawValue: fromRaw) { return p }
        if let r = catalog.routes.first(where: { $0.id == storedRouteId }) { return r.from }
        return routes.first?.from ?? .mg
    }

    private var to: PlaceID {
        if let p = PlaceID(rawValue: toRaw) { return p }
        if let r = catalog.routes.first(where: { $0.id == storedRouteId }) { return r.to }
        return routes.first(where: { $0.from == from })?.to ?? .capri
    }
    private var cal: Calendar { Rome.calendar }

    /// Щосекунди для «сьогодні» (зворотний відлік), рідше для інших днів.
    private var liveTickInterval: TimeInterval {
        cal.isDate(date, inSameDayAs: Rome.today) ? 1 : 60
    }

    private static let placeOrder: [PlaceID] = [
        .naples, .procida, .ischia, .sorrento, .positano, .amalfi, .salerno,
        .capri, .mg, .mp, .ana,
    ]

    private var fromPlaces: [PlaceID] {
        Self.sortedPlaces(Set(routes.map(\.from)))
    }

    private var toPlaces: [PlaceID] {
        Self.sortedPlaces(Set(routes.filter { $0.from == from }.map(\.to)))
    }

    private static func sortedPlaces(_ places: Set<PlaceID>) -> [PlaceID] {
        placeOrder.filter { places.contains($0) }
    }

    private func syncStoredRoute() {
        let matches = routes.filter {
            guard let from = PlaceID(rawValue: fromRaw),
                  let to = PlaceID(rawValue: toRaw) else { return false }
            return $0.from == from && $0.to == to
        }
        if let r = matches.first(where: { $0.id == storedRouteId }) {
            fromRaw = r.from.rawValue
            toRaw = r.to.rawValue
            return
        }
        if let r = matches.first {
            storedRouteId = r.id
            fromRaw = r.from.rawValue
            toRaw = r.to.rawValue
            return
        }
        if let r = routes.first(where: { $0.id == storedRouteId }) {
            fromRaw = r.from.rawValue
            toRaw = r.to.rawValue
            return
        }
        if let r = routes.first {
            fromRaw = r.from.rawValue
            toRaw = r.to.rawValue
            storedRouteId = r.id
        } else {
            storedRouteId = ""
        }
    }

    private func selectFrom(_ place: PlaceID) {
        fromRaw = place.rawValue
        let destinations = Self.sortedPlaces(Set(routes.filter { $0.from == place }.map(\.to)))
        let currentTo = PlaceID(rawValue: toRaw)
        if let currentTo, destinations.contains(currentTo) {
            // keep destination
        } else {
            toRaw = destinations.first?.rawValue ?? ""
        }
        syncStoredRoute()
    }

    private func selectTo(_ place: PlaceID) {
        toRaw = place.rawValue
        syncStoredRoute()
    }

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: liveTickInterval)) { ctx in
                let now = Rome.minutesNow(ctx.date)
                let isViewingToday = cal.isDate(date, inSameDayAs: Rome.today)
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        ScheduleLiveHeader(
                            l: l,
                            now: ctx.date,
                            nowMinutes: now,
                            viewingDate: date,
                            catalogSource: catalog.source,
                            isRefreshing: catalog.isRefreshing
                        )

                        Picker("", selection: modeSelection) {
                            ForEach(Mode.allCases) { Text(l($0.rawValue)).tag($0) }
                        }
                        .pickerStyle(.segmented)

                        favoriteRoutesBar

                        endpointPickers
                        serviceVariantChips

                        if matchingRoutes.count > 1 {
                            OperatorComparisonStrip(
                                l: l,
                                routes: matchingRoutes,
                                date: date,
                                nowMinutes: now,
                                selectedRouteId: route.id,
                                onSelect: { storedRouteId = $0.id }
                            )
                        }

                        dateNav

                        if isViewingToday {
                            NextDepartureHero(l: l, nowMinutes: now, preferredRouteId: route.id) { r, dep in
                                selection = Selection(route: r, departure: dep)
                            }
                            if RouteFavorites.ids.count > 1 {
                                FavoriteDeparturesSummary(l: l, nowMinutes: now)
                            }
                        } else {
                            RouteDayDepartureHero(l: l, route: route, date: date, nowMinutes: now) { r, dep in
                                selection = Selection(route: r, departure: dep)
                            }
                        }

                        scheduleDayBody(now: now)
                    }
                    .readableContentWidth()
                    .padding(.vertical)
                }
                .onChange(of: now) { _, newNow in
                    FavoriteWidgetWriter.update(nowMinutes: now, l: l, preferredRouteId: route.id)
                    pulseIfNextDepartureChanged(nowMinutes: newNow)
                    if #available(iOS 16.2, *) {
                        DepartureLiveActivityManager.sync(
                            nowMinutes: newNow,
                            l: l,
                            preferredRouteId: route.id
                        )
                    }
                }
                .onAppear {
                    FavoriteWidgetWriter.update(nowMinutes: now, l: l, preferredRouteId: route.id)
                    if #available(iOS 16.2, *) {
                        DepartureLiveActivityManager.sync(
                            nowMinutes: now,
                            l: l,
                            preferredRouteId: route.id
                        )
                    }
                }
            }
            .id(favoritesRevision)
            .navigationTitle(l("title"))
            .dynamicTypeSize(...DynamicTypeSize.accessibility3)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showAppearance = true } label: {
                        Image(systemName: "paintpalette")
                            .symbolRenderingMode(.hierarchical)
                    }
                    .accessibilityLabel(l("theme.title"))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    ScheduleToolbarTrailing(
                        l: l,
                        lang: lang,
                        routeId: route.id,
                        isOnline: network.isOnline,
                        catalog: catalog,
                        langRaw: $langRaw,
                        showAbout: $showAbout,
                        onToggleFavorite: {
                            RouteFavorites.toggle(route.id)
                            favoritesRevision += 1
                        }
                    )
                }
            }
            .sheet(isPresented: $showAppearance) {
                AppearanceSettingsView(l: l)
            }
            .sheet(isPresented: $showAbout) {
                AboutDataView(l: l)
            }
            .sheet(item: $selection) { sel in
                RouteMapSheet(route: sel.route, departure: sel.departure, l: l)
                    .presentationDetents([.large])
            }
            .sheet(item: $ticketSafariURL) { url in
                TicketSafariView(url: url)
                    .ignoresSafeArea()
            }
            .onAppear {
                if modeRaw == "funicular" { modeRaw = Mode.ships.rawValue }
                if fromRaw.isEmpty || toRaw.isEmpty {
                    if let r = routes.first(where: { $0.id == storedRouteId }) {
                        fromRaw = r.from.rawValue
                        toRaw = r.to.rawValue
                    } else {
                        syncStoredRoute()
                    }
                } else {
                    syncStoredRoute()
                }
            }
        }
    }

    // MARK: Відправлення / прибуття

    @ViewBuilder
    private var favoriteRoutesBar: some View {
        let ids = RouteFavorites.ids
        if !ids.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ids, id: \.self) { rid in
                        if let r = catalog.routes.first(where: { $0.id == rid }) {
                            Button {
                                modeRaw = r.mode.rawValue
                                storedRouteId = rid
                                fromRaw = r.from.rawValue
                                toRaw = r.to.rawValue
                                syncStoredRoute()
                            } label: {
                                Text(l.name(r))
                                    .font(.footnote.weight(.medium))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(
                                        storedRouteId == rid ? AppTheme.highlightFill : Color.clear,
                                        in: Capsule()
                                    )
                                    .overlay(Capsule().strokeBorder(AppTheme.cardStroke))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private var endpointPickers: some View {
        Group {
            if horizontalSizeClass == .compact && dynamicTypeSize >= .accessibility1 {
                VStack(alignment: .leading, spacing: 10) {
                    endpointMenu(title: l("tt.from"), place: from, places: fromPlaces) { selectFrom($0) }
                    Image(systemName: "arrow.down")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .accessibilityHidden(true)
                    endpointMenu(title: l("tt.to"), place: to, places: toPlaces) { selectTo($0) }
                }
            } else {
                HStack(alignment: .bottom, spacing: 10) {
                    endpointMenu(title: l("tt.from"), place: from, places: fromPlaces) { selectFrom($0) }
                    Image(systemName: "arrow.right")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 12)
                        .accessibilityHidden(true)
                    endpointMenu(title: l("tt.to"), place: to, places: toPlaces) { selectTo($0) }
                }
            }
        }
    }

    private func endpointMenu(
        title: String,
        place: PlaceID,
        places: [PlaceID],
        onSelect: @escaping (PlaceID) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            Menu {
                if places.isEmpty {
                    Text(l("none"))
                }
                ForEach(places, id: \.self) { p in
                    Button {
                        onSelect(p)
                    } label: {
                        if p == place {
                            Label(l.place(p), systemImage: "checkmark")
                        } else {
                            Text(l.place(p))
                        }
                    }
                }
            } label: {
                HStack {
                    Text(l.place(place))
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 11)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.cardStroke, lineWidth: 1))
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// Кілька ліній з одного пункту в той самий (напр. алiscafo й катамаран з Неаполя).
    @ViewBuilder
    private var serviceVariantChips: some View {
        if matchingRoutes.count > 1 {
            VStack(alignment: .leading, spacing: 6) {
                Text(l("tt.service"))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(matchingRoutes) { r in
                            Button { storedRouteId = r.id } label: {
                                Text(serviceLabel(r))
                            }
                            .buttonStyle(.bordered)
                            .tint(storedRouteId == r.id ? AppTheme.accent : .secondary)
                        }
                    }
                }
            }
        }
    }

    private func serviceLabel(_ r: Route) -> String {
        var parts: [String] = []
        if let k = r.kind { parts.append(l(k.rawValue)) }
        if let d = r.durationMin { parts.append("~\(d) \(l("m"))") }
        if parts.isEmpty { return l.name(r) }
        return parts.joined(separator: " · ")
    }

    // MARK: Навігація по даті

    private var canGoBack: Bool { date > Rome.today }
    private func step(_ n: Int) {
        let nd = cal.date(byAdding: .day, value: n, to: date)!
        date = max(nd, Rome.today)
    }
    private var dateLabel: String { l.date(date, "EEEEdMMMM") }

    private var dateNav: some View {
        VStack(spacing: 8) {
            HStack {
                Button { step(-1) } label: { Image(systemName: "chevron.left") }
                    .buttonStyle(.bordered).disabled(!canGoBack)
                Spacer()
                Text(dateLabel).font(.headline)
                Spacer()
                Button { step(1) } label: { Image(systemName: "chevron.right") }
                    .buttonStyle(.bordered)
            }
            HStack {
                Button(l("today")) { date = Rome.today }
                Button(l("tomorrow")) {
                    date = cal.date(byAdding: .day, value: 1, to: Rome.today)!
                }
            }
            .buttonStyle(.bordered).controlSize(.small)
        }
    }

    // MARK: День

    @ViewBuilder
    private func pulseIfNextDepartureChanged(nowMinutes: Int) {
        guard cal.isDate(date, inSameDayAs: Rome.today) else { return }
        let next = route.departures(on: date).first(where: { $0.minute >= nowMinutes })?.id
        defer { lastNextDepartureId = next }
        guard let next, let lastNextDepartureId, next != lastNextDepartureId else { return }
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }

    private func scheduleDayBody(now: Int) -> some View {
        ScheduleDeparturesList(
            l: l,
            route: route,
            date: date,
            nowMinutes: now,
            isOnline: network.isOnline,
            onSelect: { dep in
                selection = Selection(route: route, departure: dep)
            },
            onBuyTicket: { ticketSafariURL = $0 }
        )
        .id(route.id + "-\(date.timeIntervalSince1970)-\(catalog.source.rawValue)")
    }
}

private struct ScheduleToolbarTrailing: View {
    let l: L10n
    let lang: Lang
    let routeId: String
    let isOnline: Bool
    var catalog: TimetableCatalogStore
    @Binding var langRaw: String
    @Binding var showAbout: Bool
    let onToggleFavorite: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            if isOnline {
                Button {
                    Task { await catalog.refreshFromNetwork() }
                } label: {
                    if catalog.isRefreshing {
                        ProgressView()
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .disabled(catalog.isRefreshing)
                .accessibilityLabel(l("catalog.refresh"))
            }

            Button(action: onToggleFavorite) {
                let on = RouteFavorites.contains(routeId)
                Image(systemName: on ? "star.fill" : "star")
                    .symbolRenderingMode(on ? .multicolor : .monochrome)
            }
            .accessibilityLabel(
                RouteFavorites.contains(routeId) ? l("favorite.remove") : l("favorite.add")
            )

            Button { showAbout = true } label: {
                Image(systemName: "info.circle")
            }
            .accessibilityLabel(l("about.title"))

            LanguageMenu(lang: lang, langRaw: $langRaw)
        }
    }
}

#Preview {
    RootView()
}
