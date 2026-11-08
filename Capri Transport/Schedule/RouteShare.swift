import Foundation

enum RouteShare {
    static func departureText(route: Route, departure: Departure, on date: Date, l: L10n) -> String {
        let day = l.date(date, "yyyy-MM-dd")
        let time = Rome.hhmm(departure.minute)
        let title = l.name(route)
        var lines = ["\(title)", "\(day) · \(time)"]
        if let op = departure.op { lines.append(op) }
        if let url = route.ticketURL(for: departure) {
            lines.append(url.absoluteString)
        }
        lines.append(l("note"))
        return lines.joined(separator: "\n")
    }
}
