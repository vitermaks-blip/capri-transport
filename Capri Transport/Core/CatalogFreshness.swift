import Foundation

enum CatalogFreshness {
    /// Скільки днів минуло з `dataUpdated` (yyyy-MM-dd), 0 = сьогодні.
    static func daysSinceUpdate(_ raw: String?) -> Int? {
        guard let raw, let day = parseDay(raw) else { return nil }
        let diff = Rome.calendar.dateComponents([.day], from: day, to: Rome.today).day
        return diff
    }

    static func isStale(_ raw: String?, thresholdDays: Int = 7) -> Bool {
        guard let days = daysSinceUpdate(raw) else { return false }
        return days > thresholdDays
    }

    private static func parseDay(_ raw: String) -> Date? {
        let inFmt = DateFormatter()
        inFmt.calendar = Rome.calendar
        inFmt.locale = Locale(identifier: "en_US_POSIX")
        inFmt.timeZone = Rome.calendar.timeZone
        inFmt.dateFormat = "yyyy-MM-dd"
        return inFmt.date(from: String(raw.prefix(10)))
    }
}
