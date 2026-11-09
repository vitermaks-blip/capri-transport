import Foundation

/// Підказки про пірс (Napoli Beverello / Porta di Massa, Marina Grande).
enum RoutePier {
    static func l10nKey(route: Route, operator op: String?) -> String? {
        guard route.mode == .ships else { return nil }
        switch op {
        case "Caremar", "Medmar":
            if route.from == .naples { return "pier.porta-massa" }
            if route.to == .naples { return "pier.porta-massa.capri" }
        case "SNAV", "NLG", "Alilauro":
            if route.from == .naples { return "pier.beverello" }
            if route.to == .naples { return "pier.marina-grande" }
        default:
            break
        }
        if route.from == .naples { return "pier.naples.harbour" }
        if route.to == .naples, route.from != .capri { return "pier.marina-grande" }
        if route.from == .capri || route.to == .capri { return "pier.marina-grande" }
        return nil
    }

    static func label(route: Route, operator op: String?, l: L10n) -> String? {
        guard let key = l10nKey(route: route, operator: op) else { return nil }
        return l(key)
    }
}
