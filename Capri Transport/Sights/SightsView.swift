import SwiftUI
import CoreLocation
import MapKit

// MARK: - Модель

/// Кроки дороги. Тексти локалізовані в L10n (ключі "st.*").
enum Step: Equatable {
    case busAna             // Marina Grande → Анакапрі
    case busGrotta          // Анакапрі → Grotta Azzurra
    case busFaro            // Анакапрі → Punta Carena
    case chairlift          // Piazza Vittoria → Monte Solaro
    case walk(Int)          // пішки, хвилин

    /// Маршрут у Catalog, якщо він є в демо-розкладі.
    var timetableRouteId: String? {
        switch self {
        case .busAna: return "bus-mg-ana"
        case .busGrotta, .busFaro, .chairlift, .walk: return nil
        }
    }
}

enum SightCategory: String, CaseIterable, Identifiable, Codable {
    case landmark, restaurant, beach, viewpoint
    var id: String { rawValue }
}

struct Sight: Identifiable {
    let id: String
    let name: String              // власна назва (однакова всіма мовами)
    let category: SightCategory
    let query: String             // пошуковий запит для Google/Apple Maps
    let icon: String              // SF Symbol
    let coordinate: CLLocationCoordinate2D   // ПРИБЛИЗНІ координати для піна
    let imageName: String?        // ім’я в Assets
    let imageURL: URL?
    let steps: [Step]
    var alsoBoat = false          // є морська екскурсія

    // Навігація шукає за назвою, а не за приблизними координатами.
    var googleURL: URL {
        var c = URLComponents(string: "https://www.google.com/maps/dir/")!
        c.queryItems = [URLQueryItem(name: "api", value: "1"),
                        URLQueryItem(name: "destination", value: query)]
        return c.url!
    }
    var appleURL: URL {
        var c = URLComponents(string: "https://maps.apple.com/")!
        c.queryItems = [URLQueryItem(name: "daddr", value: query)]
        return c.url!
    }
}

// MARK: - ДАНІ з sights.json

enum SightCatalog {
    private static let payload = load()

    static let all: [Sight] = payload.places
    static let dataUpdated: String? = payload.dataUpdated

    private static func load() -> (places: [Sight], dataUpdated: String?) {
        let bundle = Bundle(for: CapriTransportBundle.self)
        guard let url = bundle.url(forResource: "sights", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            assertionFailure("sights.json не знайдено")
            return ([], nil)
        }
        do {
            let file = try JSONDecoder().decode(SightCatalogFile.self, from: data)
            let places = try file.places.map { try $0.makeSight() }
            return (places, file.dataUpdated)
        } catch {
            assertionFailure("sights.json: \(error)")
            return ([], nil)
        }
    }
}

private struct SightCatalogFile: Decodable {
    let dataUpdated: String?
    let places: [SightDTO]
}

private struct SightDTO: Decodable {
    let id, name, category, query, icon: String
    let latitude, longitude: Double
    let imageName: String?
    let imageURL: String?
    let steps: [String]
    let alsoBoat: Bool?

    func makeSight() throws -> Sight {
        guard let cat = SightCategory(rawValue: category) else {
            throw SightDecodeError.bad(id)
        }
        let parsedSteps = steps.compactMap(SightCatalogParse.step)
        return Sight(
            id: id,
            name: name,
            category: cat,
            query: query,
            icon: icon,
            coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            imageName: imageName,
            imageURL: SafeURL.sightImage(imageURL),
            steps: parsedSteps,
            alsoBoat: alsoBoat ?? false
        )
    }
}

private enum SightDecodeError: Error {
    case bad(String)
}

private enum SightCatalogParse {
    static func step(_ raw: String) -> Step? {
        if raw == "busAna" { return .busAna }
        if raw == "busGrotta" { return .busGrotta }
        if raw == "busFaro" { return .busFaro }
        if raw == "chairlift" { return .chairlift }
        if raw.hasPrefix("walk:"), let m = Int(raw.dropFirst(5)) { return .walk(m) }
        return nil
    }
}

// MARK: - Тексти кроків

extension L10n {
    func text(_ s: Step) -> String {
        switch s {
        case .busAna:    return self("st.busAna")
        case .busGrotta: return self("st.busGrotta")
        case .busFaro:   return self("st.busFaro")
        case .chairlift: return self("st.chairlift")
        case .walk(let m): return String(format: self("st.walk"), m)
        }
    }
}

// MARK: - Маршрут і час прибуття (орієнтовно, від Marina Grande)

struct SightJourneyEstimate {
    let routeDescription: String
    let arrivalMinute: Int?
    let path: [CLLocationCoordinate2D]
    let destination: CLLocationCoordinate2D
}

enum SightJourneyPlanner {
    static func estimate(sight: Sight, l: L10n, on date: Date = Rome.today, nowMinutes: Int) -> SightJourneyEstimate {
        var cursor = nowMinutes
        var parts = [l.place(.mg)]
        var hasService = true

        for step in sight.steps {
            parts.append(l.text(step))
            switch step {
            case .busAna:
                guard let rid = step.timetableRouteId,
                      let route = Catalog.all.first(where: { $0.id == rid }) else {
                    cursor += fixedDuration(step)
                    continue
                }
                let deps = route.departures(on: date)
                guard let dep = deps.first(where: { $0.minute >= cursor }) else {
                    hasService = false
                    break
                }
                cursor = dep.minute + legDuration(step, route: route)
            case .walk(let m):
                cursor += m
            case .busGrotta, .busFaro, .chairlift:
                cursor += fixedDuration(step)
            }
        }

        let arrival = hasService ? cursor : nil
        let path = buildPath(to: sight)
        return SightJourneyEstimate(
            routeDescription: parts.joined(separator: " → "),
            arrivalMinute: arrival,
            path: path,
            destination: sight.coordinate
        )
    }

    /// Лінія на карті: Marina Grande + точки з routes.json + місце призначення.
    static func buildPath(to sight: Sight) -> [CLLocationCoordinate2D] {
        var coords = [PlaceID.mg.coordinate]
        for step in sight.steps {
            switch step {
            case .busAna:
                if let rid = step.timetableRouteId,
                   let route = Catalog.all.first(where: { $0.id == rid }) {
                    appendUnique(route.path, to: &coords)
                }
            case .walk, .busGrotta, .busFaro, .chairlift:
                break
            }
        }
        appendUnique([sight.coordinate], to: &coords)
        return coords
    }

    private static func appendUnique(_ incoming: [CLLocationCoordinate2D], to coords: inout [CLLocationCoordinate2D]) {
        for p in incoming {
            if let last = coords.last, coordinatesNear(last, p) { continue }
            coords.append(p)
        }
    }

    private static func coordinatesNear(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Bool {
        abs(a.latitude - b.latitude) < 0.00015 && abs(a.longitude - b.longitude) < 0.00015
    }

    private static func legDuration(_ step: Step, route: Route) -> Int {
        if let d = route.durationMin { return d }
        switch step {
        case .busAna: return 18
        default: return fixedDuration(step)
        }
    }

    private static func fixedDuration(_ step: Step) -> Int {
        switch step {
        case .walk(let m): return m
        case .chairlift: return 12
        case .busGrotta: return 25
        case .busFaro: return 22
        case .busAna: return 18
        }
    }
}

// MARK: - Список

struct SightsView: View {
    @AppStorage("lang") private var langRaw: String = ""
    @Environment(NetworkMonitor.self) private var network
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var categoryFilter: SightCategory?
    @State private var searchText = ""
    @State private var showPhotoCredits = false
    @State private var showAppearance = false
    private var lang: Lang { Lang(rawValue: langRaw) ?? .system }
    private var l: L10n { L10n(lang: lang) }

    private var filtered: [Sight] {
        var list = SightCatalog.all
        if let categoryFilter {
            list = list.filter { $0.category == categoryFilter }
        }
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return list }
        return list.filter {
            $0.name.localizedCaseInsensitiveContains(q)
                || $0.query.localizedCaseInsensitiveContains(q)
                || l("s." + $0.id).localizedCaseInsensitiveContains(q)
        }
    }

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 30)) { ctx in
                let now = Rome.minutesNow(ctx.date)
                let t = ctx.date.timeIntervalSinceReferenceDate
                VStack(spacing: 0) {
                    SightPhotoStrip(sights: filtered, l: l, motionTime: t)
                        .padding(.top, 4)
                        .padding(.bottom, 8)
                        .background {
                            Rectangle()
                                .fill(.ultraThinMaterial)
                                .ignoresSafeArea(edges: .horizontal)
                                .shadow(color: .black.opacity(0.06), radius: 6, y: 3)
                        }

                    sightsList(nowMinutes: now)
                }
            }
            .navigationTitle(l("tab.sights"))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showAppearance = true } label: {
                        Image(systemName: "paintpalette")
                            .symbolRenderingMode(.hierarchical)
                    }
                    .accessibilityLabel(l("theme.title"))
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button { showPhotoCredits = true } label: {
                        MirroredSymbol(systemName: "c.circle", compact: true, font: .callout)
                    }
                    .accessibilityLabel(l("sights.credits.title"))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        ForEach(Lang.allCases) { lg in
                            Button(lg.rawValue.uppercased()) { langRaw = lg.rawValue }
                        }
                    } label: { Label(lang.rawValue.uppercased(), systemImage: "globe") }
                }
            }
            .sheet(isPresented: $showAppearance) {
                AppearanceSettingsView(l: l)
            }
            .sheet(isPresented: $showPhotoCredits) {
                PhotoCreditsView(l: l)
            }
            .searchable(text: $searchText, prompt: Text(l("sights.search")))
        }
    }

    private func journeyEstimates(nowMinutes: Int) -> [String: SightJourneyEstimate] {
        Dictionary(uniqueKeysWithValues: filtered.map { sight in
            (sight.id, SightJourneyPlanner.estimate(sight: sight, l: l, nowMinutes: nowMinutes))
        })
    }

    private func sightsList(nowMinutes: Int) -> some View {
        let journeys = journeyEstimates(nowMinutes: nowMinutes)
        return ScrollView {
                VStack(spacing: 12) {
                    Text("\(l("clock")): \(Rome.hhmm(nowMinutes))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .accessibilityLabel("\(l("clock")), \(Rome.hhmm(nowMinutes))")

                    categoryChips

                    ForEach(filtered) { s in
                        let journey = journeys[s.id]!
                        NavigationLink {
                            SightDetailView(sight: s, l: l)
                        } label: {
                            HStack(spacing: 12) {
                                SightPhotoView(sight: s, offlineHint: !network.isOnline)
                                    .frame(width: 72, height: 72)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(s.name).font(.headline)
                                    Text(l("sights.cat." + s.category.rawValue))
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(.secondary)
                                    SightRouteArrivalSummary(estimate: journey, l: l)
                                    Text(l("s." + s.id)).font(.subheadline)
                                        .foregroundStyle(.secondary).lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                }
                                Spacer()
                                Image(systemName: "chevron.right").font(.footnote).foregroundStyle(.tertiary)
                            }
                            .padding(12)
                            .background(.background.secondary, in: RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(.plain)
                    }

                    Button { showPhotoCredits = true } label: {
                        Text(l("sights.photoCredit"))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    Text(l("sights.note")).font(.caption).foregroundStyle(.secondary).padding(.top, 6)
                }
                .readableContentWidth()
                .padding(.vertical)
        }
        .dynamicTypeSize(...DynamicTypeSize.accessibility3)
    }

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip(title: l("sights.filter.all"), selected: categoryFilter == nil) {
                    categoryFilter = nil
                }
                ForEach(SightCategory.allCases) { cat in
                    filterChip(title: l("sights.cat." + cat.rawValue), selected: categoryFilter == cat) {
                        categoryFilter = cat
                    }
                }
            }
        }
    }

    private func filterChip(title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(selected ? .semibold : .regular))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(selected ? AppTheme.accentSoft : Color.secondary.opacity(0.10),
                          in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Карта маршруту

private struct SightRouteMapView: View {
    let sight: Sight
    let path: [CLLocationCoordinate2D]
    let l: L10n
    var offline: Bool = false

    private var mapPath: [CLLocationCoordinate2D] {
        path.count >= 2 ? path : [PlaceID.mg.coordinate, sight.coordinate]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Map(initialPosition: .rect(SightMapFit.rect(mapPath))) {
                Marker(l.place(.mg), coordinate: PlaceID.mg.coordinate).tint(AppTheme.accent)
                Marker(sight.name, coordinate: sight.coordinate).tint(.secondary)
                MapPolyline(coordinates: mapPath)
                    .stroke(AppTheme.accent.opacity(0.88), style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
            }
            .mapStyle(.standard)
            .frame(height: 200)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .accessibilityLabel(l("sights.routeMap.a11y"))

            if offline {
                Label(l("offline.maps"), systemImage: "wifi.slash")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text(l("sights.routeMap.hint"))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

private enum SightMapFit {
    static func rect(_ cs: [CLLocationCoordinate2D]) -> MKMapRect {
        var r = MKMapRect.null
        for c in cs {
            let p = MKMapPoint(c)
            r = r.union(MKMapRect(x: p.x, y: p.y, width: 0, height: 0))
        }
        let pad = max(r.width, r.height) * 0.35 + 5000
        return r.insetBy(dx: -pad, dy: -pad)
    }
}

// MARK: - Маршрут / прибуття (UI)

private struct SightRouteArrivalSummary: View {
    let estimate: SightJourneyEstimate
    let l: L10n

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Label {
                Text(estimate.routeDescription)
                    .lineLimit(2)
            } icon: {
                Image(systemName: "map")
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            if let minute = estimate.arrivalMinute {
                Label {
                    Text("\(l("sights.arrivalAt")) · \(Rome.hhmm(minute))")
                } icon: {
                    Image(systemName: "flag.checkered")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.highlightText)
            } else {
                Text(l("sights.noService"))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Деталі й навігація

struct SightDetailView: View {
    let sight: Sight
    let l: L10n
    @Environment(NetworkMonitor.self) private var network
    @Environment(\.appState) private var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { ctx in
            let now = Rome.minutesNow(ctx.date)
            let journey = SightJourneyPlanner.estimate(sight: sight, l: l, nowMinutes: now)
            detailScroll(journey: journey, capriTime: ctx.date)
        }
        .navigationTitle(sight.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func detailScroll(journey: SightJourneyEstimate, capriTime: Date) -> some View {
        let t = capriTime.timeIntervalSinceReferenceDate
        let motion = SightPhotoMotion.kenBurns(sightId: sight.id, t: t, enabled: !reduceMotion)
        return ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                SightPhotoView(
                    sight: sight,
                    offlineHint: !network.isOnline,
                    drift: motion.drift,
                    zoom: motion.zoom
                )
                    .frame(height: 260)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .accessibilityLabel(sight.name)

                VStack(alignment: .leading, spacing: 10) {
                    Text(l("sights.route")).font(.subheadline.weight(.semibold))
                    SightRouteMapView(sight: sight, path: journey.path, l: l, offline: !network.isOnline)
                    Text(journey.routeDescription)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if let minute = journey.arrivalMinute {
                        HStack(spacing: 8) {
                            Text(l("sights.arrivalAt"))
                                .font(.subheadline.weight(.semibold))
                            Text(Rome.hhmm(minute))
                                .font(.title3.weight(.bold))
                                .foregroundStyle(AppTheme.accent)
                        }
                        Text(l("sights.arrival.hint"))
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    } else {
                        Text(l("sights.noService"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppTheme.highlightFill.opacity(0.55), in: RoundedRectangle(cornerRadius: 14))

                Text(l("sights.cat." + sight.category.rawValue))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text(l("s." + sight.id)).font(.body)

                Text(l("sights.how")).font(.title3.bold()).padding(.top, 4)

                VStack(alignment: .leading, spacing: 10) {
                    plainStepRow(n: 1, text: l("st.arrive"))
                    ForEach(Array(sight.steps.enumerated()), id: \.offset) { i, s in
                        stepRow(n: i + 2, step: s, text: l.text(s))
                    }
                    if sight.alsoBoat {
                        Label(l("st.boat"), systemImage: "ferry").font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.background.secondary, in: RoundedRectangle(cornerRadius: 14))

                Text(l("sights.note")).font(.caption).foregroundStyle(.secondary)
            }
            .readableContentWidth()
            .padding(.vertical)
        }
        .dynamicTypeSize(...DynamicTypeSize.accessibility3)
    }

    private func plainStepRow(n: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(n)").font(.caption.bold()).foregroundStyle(.white)
                .frame(width: 22, height: 22).background(AppTheme.accent.opacity(0.75), in: Circle())
            Text(text).font(.subheadline)
        }
    }

    private func stepRow(n: Int, step: Step, text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 10) {
                Text("\(n)").font(.caption.bold()).foregroundStyle(.white)
                    .frame(width: 22, height: 22).background(AppTheme.accent.opacity(0.75), in: Circle())
                Text(text).font(.subheadline)
            }
            if let routeId = step.timetableRouteId,
               let route = Catalog.all.first(where: { $0.id == routeId }) {
                Button { openTimetable(route) } label: {
                    Label(l("sights.showTimetable"), systemImage: "clock")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .padding(.leading, 32)
            }
        }
    }

    private func openTimetable(_ route: Route) {
        appState.show(routeID: route.id)
    }
}

#Preview { RootView() }
