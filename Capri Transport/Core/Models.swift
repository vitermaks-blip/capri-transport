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

    /// Хвилини до відправлення в Europe/Rome (nil, якщо час уже минув).
    static func minutesUntil(day: Date, departureMinute: Int, from reference: Date = .now) -> Int? {
        var comps = calendar.dateComponents([.year, .month, .day], from: day)
        comps.hour = departureMinute / 60
        comps.minute = departureMinute % 60
        comps.second = 0
        guard let at = calendar.date(from: comps) else { return nil }
        let delta = at.timeIntervalSince(reference)
        guard delta >= 0 else { return nil }
        return Int(delta / 60)
    }
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

// MARK: - ДАНІ розкладу (бандл + мережевий фід)

final class CapriTransportBundle: NSObject {}

enum Catalog {
    static var all: [Route] { CatalogSnapshot.shared.routes }
    static var dataUpdated: String? { CatalogSnapshot.shared.dataUpdated }
    static var source: TimetableDataSource { CatalogSnapshot.shared.source }

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
}
