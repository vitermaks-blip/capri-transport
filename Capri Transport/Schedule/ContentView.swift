import SwiftUI

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
    @Environment(NetworkMonitor.self) private var network
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
    private var routes: [Route] { Catalog.all.filter { $0.mode == mode } }
    private var matchingRoutes: [Route] {
        routes.filter { $0.from == from && $0.to == to }
    }
    private var route: Route {
        let fallback = routes.first ?? Catalog.all.first ?? Route(
            id: "empty", mode: .ships, from: .mg, to: .capri
        )
        if let r = matchingRoutes.first(where: { $0.id == storedRouteId }) { return r }
        if let r = matchingRoutes.first { return r }
        if let r = routes.first(where: { $0.id == storedRouteId }) { return r }
        return fallback
    }
    private var from: PlaceID {
        if let p = PlaceID(rawValue: fromRaw) { return p }
        if let r = Catalog.all.first(where: { $0.id == storedRouteId }) { return r.from }
        return routes.first?.from ?? .mg
    }

    private var to: PlaceID {
        if let p = PlaceID(rawValue: toRaw) { return p }
        if let r = Catalog.all.first(where: { $0.id == storedRouteId }) { return r.to }
        return routes.first(where: { $0.from == from })?.to ?? .capri
    }
    private var cal: Calendar { Rome.calendar }

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
            TimelineView(.periodic(from: .now, by: 30)) { ctx in
                let now = Rome.minutesNow(ctx.date)
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        DataDisclaimerBanner(l: l)
                        FavoriteDeparturesSummary(l: l, nowMinutes: now)

                        Text("\(l("clock")): \(Rome.hhmm(now))")
                            .font(.footnote).foregroundStyle(.secondary)

                        Picker("", selection: modeSelection) {
                            ForEach(Mode.allCases) { Text(l($0.rawValue)).tag($0) }
                        }
                        .pickerStyle(.segmented)

                        favoriteRoutesBar

                        endpointPickers
                        serviceVariantChips

                        dateNav

                        dayView(now: now)

                        Text(l("tip") + " " + l("note"))
                            .font(.caption).foregroundStyle(.secondary).padding(.top, 8)
                    }
                    .readableContentWidth()
                    .padding(.vertical)
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
                    HStack(spacing: 16) {
                        Button {
                            RouteFavorites.toggle(route.id)
                            favoritesRevision += 1
                        } label: {
                            let on = RouteFavorites.contains(route.id)
                            Image(systemName: on ? "star.fill" : "star")
                                .symbolRenderingMode(on ? .multicolor : .monochrome)
                        }
                        .accessibilityLabel(
                            RouteFavorites.contains(route.id) ? l("favorite.remove") : l("favorite.add")
                        )

                        Button { showAbout = true } label: {
                            Image(systemName: "info.circle")
                        }
                        .accessibilityLabel(l("about.title"))

                        Menu {
                            ForEach(Lang.allCases) { lg in
                                Button(lg.rawValue.uppercased()) { langRaw = lg.rawValue }
                            }
                        } label: { Label(lang.rawValue.uppercased(), systemImage: "globe") }
                    }
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
                        if let r = Catalog.all.first(where: { $0.id == rid }) {
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
                            .tint(route.id == r.id ? AppTheme.accent : .secondary)
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

    private func nextService(after today: Date) -> (Date, Departure)? {
        guard let hit = TimetableQuery.nextService(route: route, from: today, after: Rome.minutesNow()) else {
            return nil
        }
        return (hit.date, hit.departure)
    }

    @ViewBuilder
    private func dayView(now: Int) -> some View {
        let isToday = cal.isDate(date, inSameDayAs: Rome.today)
        let deps = route.departures(on: date)

        // Жовта картка
        Group {
            if isToday, let up = deps.first(where: { $0.minute >= now }) {
                card(title: Rome.hhmm(up.minute),
                     subtitle: [l.until(up.minute - now), up.op, l.info(route, withOperators: false)]
                        .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "),
                     tap: Selection(route: route, departure: up))
            } else if isToday {
                let next = nextService(after: Rome.today)
                card(title: deps.isEmpty ? l("none") : l("done"),
                     subtitle: next.map { "\(l("nextDep")): \(l.date($0.0, "dMMM")), \(Rome.hhmm($0.1.minute))" } ?? l("none"),
                     tap: nil)
            } else if let first = deps.first {
                card(title: Rome.hhmm(first.minute),
                     subtitle: "\(l("count")): \(deps.count) · \(l.info(route))",
                     tap: Selection(route: route, departure: first))
            } else {
                card(title: l("none"), subtitle: l.info(route), tap: nil)
            }
        }

        VStack(spacing: 0) {
            ForEach(deps) { dep in
                let past = isToday && dep.minute < now
                HStack(spacing: 8) {
                    Button { selection = Selection(route: route, departure: dep) } label: {
                        HStack {
                            Text(Rome.hhmm(dep.minute)).font(.title3.monospacedDigit().weight(.semibold))
                            Text(dep.op ?? "").font(.subheadline).foregroundStyle(.secondary)
                            Spacer()
                            if isToday {
                                Text(past ? l("gone") : l.until(dep.minute - now))
                                    .font(.footnote).foregroundStyle(.secondary)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if let url = route.ticketURL(for: dep) {
                        if network.isOnline {
                            Link(destination: url) {
                                MirroredSymbol(systemName: "ticket", compact: true, font: .callout)
                                    .frame(width: 36, height: 36)
                                    .background(AppTheme.accentSoft, in: Circle())
                            }
                            .accessibilityLabel(l("buyTicket"))
                        } else {
                            Image(systemName: "ticket")
                                .font(.body)
                                .foregroundStyle(.tertiary)
                                .frame(width: 36, height: 36)
                                .accessibilityLabel(l("buyTicket"))
                        }
                    }
                }
                .padding(.vertical, 12).padding(.horizontal, 14)
                .opacity(past ? 0.4 : 1)
                .accessibilityHint(l("tip"))
                .contextMenu {
                    ShareLink(
                        item: RouteShare.departureText(route: route, departure: dep, on: date, l: l),
                        subject: Text(l.name(route)),
                        message: Text(Rome.hhmm(dep.minute))
                    ) {
                        Label(l("share.departure"), systemImage: "square.and.arrow.up")
                    }
                    Button { selection = Selection(route: route, departure: dep) } label: {
                        Label(l("sights.routeMap.a11y"), systemImage: "map")
                    }
                    if let link = appState.deepLinkURL(routeID: route.id) {
                        ShareLink(item: link, subject: Text(l.name(route))) {
                            Label(l("about.deeplink.share"), systemImage: "link")
                        }
                    }
                }
                Divider()
            }
        }
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 14))
    }

    private func card(title: String, subtitle: String, tap: Selection?) -> some View {
        Button { if let tap { selection = tap } } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.largeTitle.weight(.heavy)).monospacedDigit()
                    .minimumScaleFactor(0.65)
                    .lineLimit(1)
                Text(subtitle).font(.subheadline)
            }
            .foregroundStyle(AppTheme.highlightText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(AppTheme.highlightFill, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(AppTheme.cardStroke))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    RootView()
}
