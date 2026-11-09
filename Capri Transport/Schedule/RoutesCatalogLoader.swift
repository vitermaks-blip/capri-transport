import Foundation
import CoreLocation

struct RoutesCatalogPayload {
    let routes: [Route]
    let dataUpdated: String?
}

enum TimetableDataSource: String, Equatable {
    case bundle
    case cache
    case network
}

enum TimetableFeedURL {
    /// Hosted feed (same JSON schema as bundled `routes.json`). Override via Info.plist `CapriTimetableFeedURL`.
    private static let builtin = "https://raw.githubusercontent.com/maksym-viter/capri-transport/main/api/routes.json"

    static var url: URL? {
        if let custom = Bundle.main.object(forInfoDictionaryKey: "CapriTimetableFeedURL") as? String {
            let trimmed = custom.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty, let u = SafeURL.feed(trimmed) { return u }
        }
        return SafeURL.feed(builtin)
    }
}

enum RoutesCatalogLoader {
    private static let cacheFileName = "routes-feed-cache.json"

    static func loadBundled() -> RoutesCatalogPayload {
        load(data: readBundledData(), source: "bundle")
    }

    static func loadCache() -> RoutesCatalogPayload? {
        guard let url = cacheFileURL(),
              let data = try? Data(contentsOf: url) else { return nil }
        return load(data: data, source: "cache")
    }

    static func saveCache(_ data: Data) {
        guard let url = cacheFileURL() else { return }
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? data.write(to: url, options: .atomic)
    }

    static func decode(_ data: Data) throws -> RoutesCatalogPayload {
        let file = try JSONDecoder().decode(CatalogFile.self, from: data)
        let routes = try file.routes.map { try $0.makeRoute() }
        return RoutesCatalogPayload(routes: routes, dataUpdated: file.dataUpdated)
    }

    private static func load(data: Data, source: String) -> RoutesCatalogPayload {
        do {
            return try decode(data)
        } catch {
            assertionFailure("\(source) routes catalog: \(error)")
            return RoutesCatalogPayload(routes: [], dataUpdated: nil)
        }
    }

    private static func readBundledData() -> Data {
        let bundle = Bundle(for: CapriTransportBundle.self)
        guard let url = bundle.url(forResource: "routes", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            assertionFailure("routes.json не знайдено в бандлі")
            return Data()
        }
        return data
    }

    private static func cacheFileURL() -> URL? {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent(cacheFileName)
    }
}

// MARK: - routes.json decoding

struct CatalogFile: Decodable {
    let dataUpdated: String?
    let routes: [RouteDTO]
}

struct RouteDTO: Decodable {
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

struct DepartureDTO: Decodable {
    let time: String
    let op: String?
    let ticketURL: String?
}

struct IntervalDTO: Decodable {
    let start, end: String
    let every: Int
}

struct SeasonDTO: Decodable {
    let from, through: Int
}

enum CatalogDecodeError: Error {
    case badRoute(String)
}

enum CatalogParse {
    static func hhmm(_ s: String) -> Int {
        let p = s.split(separator: ":").compactMap { Int($0) }
        guard p.count == 2 else { return 0 }
        return p[0] * 60 + p[1]
    }
}
