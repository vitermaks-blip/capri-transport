import XCTest
@testable import Capri_Transport

// Tests remain in a single file; folder mirrors app modules (Schedule, Core, …).

final class RouteTests: XCTestCase {

    private func rome(_ y: Int, _ m: Int, _ d: Int) -> Date {
        Rome.calendar.date(from: DateComponents(year: y, month: m, day: d, hour: 12))!
    }

    func testIntervalGeneration() {
        let bus = Catalog.all.first { $0.id == "bus-mg-ana" }!
        let deps = bus.departures(on: rome(2026, 7, 15))
        XCTAssertEqual(deps.first?.minute, 6 * 60)
        XCTAssertEqual(deps.count, 53)
        XCTAssertTrue(deps.allSatisfy { $0.op == "ATC" })
    }

    func testExplicitTimesCarryOperator() {
        let ship = Catalog.all.first { $0.id == "ship-nap-cap" }!
        let first = ship.departures(on: rome(2026, 7, 15)).first
        XCTAssertEqual(first?.minute, 7 * 60)
        XCTAssertEqual(first?.op, "Medmar")
    }

    func testSeasonBoundaries() {
        let hydro = Catalog.all.first { $0.id == "ship-sor-cap" }!
        XCTAssertTrue(hydro.departures(on: rome(2026, 3, 31)).isEmpty)
        XCTAssertFalse(hydro.departures(on: rome(2026, 4, 1)).isEmpty)
        XCTAssertFalse(hydro.departures(on: rome(2026, 10, 31)).isEmpty)
        XCTAssertTrue(hydro.departures(on: rome(2026, 11, 1)).isEmpty)
    }

    func testWeekdayFilter() {
        let day = rome(2026, 7, 15)
        let wd = Rome.calendar.component(.weekday, from: day)
        let other = wd == 1 ? 2 : 1
        let r = Route(id: "t", mode: .buses, from: .mg, to: .ana,
                      interval: (360, 420, 30), op: "X", weekdays: [wd])
        XCTAssertEqual(r.departures(on: day).count, 3)
        let r2 = Route(id: "t2", mode: .buses, from: .mg, to: .ana,
                       interval: (360, 420, 30), op: "X", weekdays: [other])
        XCTAssertTrue(r2.departures(on: day).isEmpty)
    }

    func testShipEndpointIsMarinaGrande() {
        let ship = Catalog.all.first { $0.id == "ship-nap-cap" }!
        XCTAssertEqual(ship.endpoint(.capri).latitude, PlaceID.mg.coordinate.latitude)
    }
}

final class L10nTests: XCTestCase {
    func testEveryKeyHasFiveTranslations() {
        for (key, row) in L10n.table {
            XCTAssertEqual(row.count, Lang.allCases.count, "Ключ \(key)")
            XCTAssertTrue(row.allSatisfy { !$0.isEmpty }, "Порожній переклад у \(key)")
        }
    }
}

final class CatalogMetaTests: XCTestCase {
    func testRoutesBundleHasUpdateStamp() {
        XCTAssertEqual(Catalog.dataUpdated, "2026-11-08")
        XCTAssertFalse(Catalog.all.isEmpty)
    }

    func testBundledCatalogDecodes() throws {
        let bundled = RoutesCatalogLoader.loadBundled()
        XCTAssertFalse(bundled.routes.isEmpty)
        XCTAssertEqual(bundled.dataUpdated, "2026-11-08")
    }

    func testFeedURLAllowlist() {
        XCTAssertNotNil(SafeURL.feed("https://raw.githubusercontent.com/org/repo/main/api/routes.json"))
        XCTAssertNil(SafeURL.feed("https://evil.example/routes.json"))
    }
}

final class AppStateTests: XCTestCase {
    func testShowRouteSwitchesTabAndMode() {
        let suite = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let app = AppState(defaults: suite)
        app.show(routeID: "bus-mg-ana")
        XCTAssertEqual(app.tab, .timetable)
        XCTAssertEqual(app.mode, .buses)
        XCTAssertEqual(app.routeID, "bus-mg-ana")
        XCTAssertEqual(AppState(defaults: suite).routeID, "bus-mg-ana")
    }

    func testDeepLinkOpensRoute() {
        let suite = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let app = AppState(defaults: suite)
        let url = URL(string: "capritransport://route/ship-nap-cap")!
        XCTAssertTrue(app.open(url: url))
        XCTAssertEqual(app.routeID, "ship-nap-cap")
        XCTAssertEqual(app.mode, .ships)
    }

    func testDeepLinkRejectsUnknownRoute() {
        let suite = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let app = AppState(defaults: suite)
        let url = URL(string: "capritransport://route/not-a-route")!
        XCTAssertFalse(app.open(url: url))
    }
}

final class TimetableQueryTests: XCTestCase {
    func testNextServiceFindsSameDay() {
        let bus = Catalog.all.first { $0.id == "bus-mg-ana" }!
        let day = Rome.calendar.date(from: DateComponents(year: 2026, month: 7, day: 15))!
        let hit = TimetableQuery.nextService(route: bus, from: day, after: 6 * 60)
        XCTAssertEqual(hit?.departure.minute, 6 * 60)
    }
}

final class SightJourneyTests: XCTestCase {
    func testJourneyWithBusAnaHasArrival() {
        let sight = SightCatalog.all.first { $0.steps.contains { step in
            if case .busAna = step { return true }
            return false
        } }!
        let l = L10n(lang: .en)
        let est = SightJourneyPlanner.estimate(sight: sight, l: l, nowMinutes: 6 * 60)
        XCTAssertNotNil(est.arrivalMinute)
        XCTAssertTrue(est.routeDescription.contains("→"))
    }
}

final class RouteShareTests: XCTestCase {
    func testShareTextContainsTime() {
        let route = Catalog.all.first { $0.id == "bus-mg-ana" }!
        let dep = route.departures(on: Rome.today).first!
        let text = RouteShare.departureText(route: route, departure: dep, on: Rome.today, l: L10n(lang: .en))
        XCTAssertTrue(text.contains(Rome.hhmm(dep.minute)))
    }
}

final class SightCatalogTests: XCTestCase {
    func testEverySightHasDescriptionKey() {
        for sight in SightCatalog.all {
            XCTAssertNotNil(L10n.table["s." + sight.id], "L10n s.\(sight.id)")
        }
    }

    func testBundledPhotosHaveCredits() {
        let credited = Set(PhotoCreditsCatalog.all.map(\.sightId))
        for sight in SightCatalog.all where sight.imageName != nil {
            XCTAssertTrue(credited.contains(sight.id), "photo-credits для \(sight.id)")
        }
    }

    func testAuroraReachesTownOnFoot() {
        let aurora = SightCatalog.all.first { $0.id == "aurora" }!
        XCTAssertFalse(aurora.steps.contains(.busAna))
        XCTAssertTrue(aurora.steps.contains(.walk(25)))
    }
}

final class CatalogFreshnessTests: XCTestCase {
    func testStaleAfterSevenDays() {
        XCTAssertFalse(CatalogFreshness.isStale("2026-11-08"))
        XCTAssertTrue(CatalogFreshness.isStale("2026-10-01"))
    }
}

final class AppStateDeepLinkTests: XCTestCase {
    func testSightDeepLink() {
        let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let state = AppState(defaults: defaults)
        let url = URL(string: "capritransport://sight/faraglioni")!
        XCTAssertTrue(state.open(url: url))
        XCTAssertEqual(state.pendingSightID, "faraglioni")
        XCTAssertEqual(state.tab, .sights)
    }
}

final class RouteFavoritesTests: XCTestCase {
    private var suite: UserDefaults!

    override func setUp() {
        suite = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        RouteFavorites.defaults = suite
    }

    override func tearDown() {
        RouteFavorites.defaults = .standard
    }

    func testToggleFavorite() {
        XCTAssertFalse(RouteFavorites.contains("bus-mg-ana"))
        RouteFavorites.toggle("bus-mg-ana")
        XCTAssertTrue(RouteFavorites.contains("bus-mg-ana"))
        RouteFavorites.toggle("bus-mg-ana")
        XCTAssertFalse(RouteFavorites.contains("bus-mg-ana"))
    }
}
