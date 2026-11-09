import Foundation

enum SightShare {
    static func text(sight: Sight, l: L10n, deepLink: URL?) -> String {
        var lines = [sight.name, l("s." + sight.id)]
        if let deepLink {
            lines.append(deepLink.absoluteString)
        }
        lines.append(l("sights.note"))
        return lines.joined(separator: "\n")
    }
}
