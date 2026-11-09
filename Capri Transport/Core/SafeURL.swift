import Foundation

/// Перевірка URL з бандлу (JSON) перед відкриттям у браузері або завантаженням.
enum SafeURL {
    /// Дозволені хости для квитків (доповнюйте разом із routes.json).
    private static let ticketHosts: Set<String> = [
        "caremar.it", "www.caremar.it",
        "navlib.it", "www.navlib.it",
        "snav.it", "www.snav.it",
        "alilauro.it", "www.alilauro.it",
        "medmargroup.it", "www.medmargroup.it",
        "atc.capri.it", "www.atc.capri.it",
        "travelmar.it", "www.travelmar.it",
    ]

    private static let imageHosts: Set<String> = [
        "upload.wikimedia.org", "commons.wikimedia.org", "thumb.wikimedia.org",
    ]

    /// HTTPS hosts allowed for remote timetable JSON (`CapriTimetableFeedURL`).
    private static let feedHosts: Set<String> = [
        "raw.githubusercontent.com",
        "gist.githubusercontent.com",
        "origin.cursor.com",
    ]

    static func https(_ raw: String?) -> URL? {
        guard let raw, let url = URL(string: raw),
              let scheme = url.scheme?.lowercased(), scheme == "https",
              let host = url.host?.lowercased(), !host.isEmpty,
              url.user == nil, url.password == nil else { return nil }
        return url
    }

    static func ticket(_ raw: String?) -> URL? {
        guard let url = https(raw), let host = url.host?.lowercased() else { return nil }
        if ticketHosts.contains(host) { return url }
        if ticketHosts.contains(where: { host == $0 || host.hasSuffix(".\($0)" ) }) { return url }
        return nil
    }

    static func sightImage(_ raw: String?) -> URL? {
        guard let url = https(raw), let host = url.host?.lowercased() else { return nil }
        return imageHosts.contains(where: { host == $0 || host.hasSuffix(".\($0)" ) }) ? url : nil
    }

    static func feed(_ raw: String?) -> URL? {
        guard let url = https(raw), let host = url.host?.lowercased() else { return nil }
        return feedHosts.contains(where: { host == $0 || host.hasSuffix(".\($0)") }) ? url : nil
    }

}
