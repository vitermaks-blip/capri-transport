import Foundation
import CoreLocation

// MARK: - Час на Капрі

enum Rome {
    static let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Europe/Rome")!
        c.firstWeekday = 2 // понеділок
        return c
    }()
    static var today: Date { calendar.startOfDay(for: .now) }
    static func minutesNow(_ d: Date = .now) -> Int {
        let c = calendar.dateComponents([.hour, .minute], from: d)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }
    static func hhmm(_ m: Int) -> String { String(format: "%02d:%02d", (m / 60) % 24, m % 60) }
}

// MARK: - Моделі

enum Mode: String, CaseIterable, Identifiable {
    case ships, buses
    var id: String { rawValue }
}

enum VesselKind: String { case cat, hyd }

enum PlaceID: String, CaseIterable {
    case naples, procida, ischia, sorrento, positano, amalfi, salerno
    case capri, mg, mp, ana
    var coordinate: CLLocationCoordinate2D {
        switch self {
        case .naples:   return CLLocationCoordinate2D(latitude: 40.8372, longitude: 14.2529)
        case .procida:  return CLLocationCoordinate2D(latitude: 40.7656, longitude: 14.0299)
        case .ischia:   return CLLocationCoordinate2D(latitude: 40.7436, longitude: 13.9428)
        case .sorrento: return CLLocationCoordinate2D(latitude: 40.6270, longitude: 14.3730)
        case .positano: return CLLocationCoordinate2D(latitude: 40.6281, longitude: 14.4849)
        case .amalfi:   return CLLocationCoordinate2D(latitude: 40.6340, longitude: 14.6027)
        case .salerno:  return CLLocationCoordinate2D(latitude: 40.6820, longitude: 14.7681)
        case .capri:    return CLLocationCoordinate2D(latitude: 40.5507, longitude: 14.2430)
        case .mg:       return CLLocationCoordinate2D(latitude: 40.5596, longitude: 14.2386)
        case .mp:       return CLLocationCoordinate2D(latitude: 40.5450, longitude: 14.2433)
        case .ana:      return CLLocationCoordinate2D(latitude: 40.5586, longitude: 14.2217)
        }
    }
}

struct Departure: Identifiable, Hashable {
    let minute: Int      // хвилини від півночі
    let op: String?      // перевізник
    var ticketURL: URL? = nil
    var id: Int { minute }
}

struct Route: Identifiable {
    let id: String
    let mode: Mode
    let from: PlaceID
    let to: PlaceID
    var explicit: [Departure] = []
    var interval: (start: Int, end: Int, every: Int)? = nil
    var op: String? = nil
    var kind: VesselKind? = nil
    var durationMin: Int? = nil
    var price: Double? = nil
    var season: ClosedRange<Int>? = nil     // ММДД, напр. 401...1031
    var weekdays: Set<Int>? = nil           // 1 = неділя … 7 = субота
    var way: [CLLocationCoordinate2D] = []  // проміжні точки дороги
    var ticketURL: URL? = nil
    var ticketByOperator: [String: URL] = [:]

    /// Посилання на покупку квитка (з routes.json; перевірте актуальність).
    func ticketURL(for departure: Departure) -> URL? {
        if let u = departure.ticketURL { return u }
        if let op = departure.op, let u = ticketByOperator[op] { return u }
        return ticketURL
    }

    /// Кораблі приходять у Marina Grande, а не в «центр» Капрі.
    func endpoint(_ p: PlaceID) -> CLLocationCoordinate2D {
        (mode == .ships && p == .capri) ? PlaceID.mg.coordinate : p.coordinate
    }
    var path: [CLLocationCoordinate2D] {
        mode == .ships || way.isEmpty ? [endpoint(from), endpoint(to)] : way
    }

    func departures(on date: Date) -> [Departure] {
        let c = Rome.calendar.dateComponents([.month, .day, .weekday], from: date)
        if let wd = weekdays, !wd.contains(c.weekday ?? 0) { return [] }
        if let s = season, !s.contains((c.month ?? 0) * 100 + (c.day ?? 0)) { return [] }
        if !explicit.isEmpty { return explicit.map { Departure(minute: $0.minute, op: $0.op ?? op) } }
        guard let i = interval, i.every > 0, i.start <= i.end else { return [] }
        let cap = 500
        var out: [Departure] = []
        out.reserveCapacity(min(cap, (i.end - i.start) / i.every + 1))
        for m in stride(from: i.start, through: i.end, by: i.every) {
            out.append(Departure(minute: m, op: op))
            if out.count >= cap { break }
        }
        return out
    }

    /// Усі перевізники маршруту через кому.
    var operators: String {
        var seen: [String] = []
        for o in ([op] + explicit.map { $0.op }).compactMap({ $0 }) where !seen.contains(o) { seen.append(o) }
        return seen.joined(separator: ", ")
    }
}

// MARK: - ДАНІ з routes.json (демо; замініть на актуальний розклад)

final class CapriTransportBundle: NSObject {}

enum Catalog {
    private static let payload = loadCatalog()

    static let all: [Route] = payload.routes
    static let dataUpdated: String? = payload.dataUpdated

    /// ISO-дата з `routes.json` для відображення в UI.
    static var dataUpdatedLabel: String? {
        guard let raw = dataUpdated else { return nil }
        let inFmt = DateFormatter()
        inFmt.calendar = Rome.calendar
        inFmt.locale = Locale(identifier: "en_US_POSIX")
        inFmt.dateFormat = "yyyy-MM-dd"
        guard let d = inFmt.date(from: raw) else { return raw }
        let out = DateFormatter()
        out.calendar = Rome.calendar
        out.timeZone = Rome.calendar.timeZone
        out.setLocalizedDateFormatFromTemplate("dMMMMyyyy")
        return out.string(from: d)
    }

    private static func loadCatalog() -> (routes: [Route], dataUpdated: String?) {
        let bundle = Bundle(for: CapriTransportBundle.self)
        guard let url = bundle.url(forResource: "routes", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            assertionFailure("routes.json не знайдено в бандлі")
            return ([], nil)
        }
        do {
            let file = try JSONDecoder().decode(CatalogFile.self, from: data)
            let routes = try file.routes.map { try $0.makeRoute() }
            return (routes, file.dataUpdated)
        } catch {
            assertionFailure("routes.json: \(error)")
            return ([], nil)
        }
    }
}

// MARK: - Декодування routes.json

private struct CatalogFile: Decodable {
    let dataUpdated: String?
    let routes: [RouteDTO]
}

private struct RouteDTO: Decodable {
    let id: String
    let mode: String
    let from: String
    let to: String
    let kind: String?
    let durationMin: Int?
    let price: Double?
    let op: String?
    let interval: IntervalDTO?
    let season: SeasonDTO?
    let weekdays: [Int]?
    let way: [[Double]]?
    let departures: [DepartureDTO]?
    let ticketURL: String?
    let ticketByOperator: [String: String]?

    func makeRoute() throws -> Route {
        guard let mode = Mode(rawValue: mode),
              let from = PlaceID(rawValue: from),
              let to = PlaceID(rawValue: to) else {
            throw CatalogDecodeError.badRoute(id)
        }
        let explicit: [Departure] = (departures ?? []).map {
            Departure(
                minute: CatalogParse.hhmm($0.time),
                op: $0.op,
                ticketURL: SafeURL.ticket($0.ticketURL)
            )
        }
        let operatorTickets = (ticketByOperator ?? [:]).compactMapValues(SafeURL.ticket)
        let intervalTriplet: (Int, Int, Int)? = interval.flatMap { iv in
            guard iv.every > 0 else { return nil }
            return (CatalogParse.hhmm(iv.start), CatalogParse.hhmm(iv.end), iv.every)
        }
        let seasonRange: ClosedRange<Int>? = season.map { $0.from ... $0.through }
        let waypoints: [CLLocationCoordinate2D] = (way ?? []).map {
            guard $0.count == 2 else { return CLLocationCoordinate2D() }
            return CLLocationCoordinate2D(latitude: $0[0], longitude: $0[1])
        }
        return Route(
            id: id,
            mode: mode,
            from: from,
            to: to,
            explicit: explicit,
            interval: intervalTriplet,
            op: op,
            kind: kind.flatMap(VesselKind.init(rawValue:)),
            durationMin: durationMin,
            price: price,
            season: seasonRange,
            weekdays: weekdays.map(Set.init),
            way: waypoints,
            ticketURL: SafeURL.ticket(ticketURL),
            ticketByOperator: operatorTickets
        )
    }
}

private struct DepartureDTO: Decodable {
    let time: String
    let op: String?
    let ticketURL: String?
}

private struct IntervalDTO: Decodable {
    let start, end: String
    let every: Int
}

private struct SeasonDTO: Decodable {
    let from, through: Int
}

private enum CatalogDecodeError: Error {
    case badRoute(String)
}

private enum CatalogParse {
    static func hhmm(_ s: String) -> Int {
        let p = s.split(separator: ":").compactMap { Int($0) }
        guard p.count == 2 else { return 0 }
        return p[0] * 60 + p[1]
    }
}
