import Foundation

enum TimetableQuery {
    static func nextDeparture(route: Route, on date: Date, after minutes: Int) -> Departure? {
        route.departures(on: date).first { $0.minute >= minutes }
    }

    /// Найближчий рейс сьогодні або в межах 60 днів.
    static func nextService(route: Route, from startDate: Date, after nowMinutes: Int) -> (date: Date, departure: Departure)? {
        let cal = Rome.calendar
        if let dep = nextDeparture(route: route, on: startDate, after: nowMinutes) {
            return (startDate, dep)
        }
        for offset in 1...60 {
            guard let day = cal.date(byAdding: .day, value: offset, to: startDate),
                  let first = route.departures(on: day).first else { continue }
            return (day, first)
        }
        return nil
    }

    static func route(id: String) -> Route? {
        Catalog.all.first { $0.id == id }
    }
}
