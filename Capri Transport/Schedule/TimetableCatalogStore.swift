import Foundation
import Observation

/// Thread-safe snapshot for `Catalog` and background readers.
final class CatalogSnapshot: @unchecked Sendable {
    static let shared = CatalogSnapshot()

    private let lock = NSLock()
    private var _routes: [Route]
    private var _dataUpdated: String?
    private var _source: TimetableDataSource

    var routes: [Route] {
        lock.lock(); defer { lock.unlock() }
        return _routes
    }

    var dataUpdated: String? {
        lock.lock(); defer { lock.unlock() }
        return _dataUpdated
    }

    var source: TimetableDataSource {
        lock.lock(); defer { lock.unlock() }
        return _source
    }

    init() {
        let bundled = RoutesCatalogLoader.loadBundled()
        _routes = bundled.routes
        _dataUpdated = bundled.dataUpdated
        _source = .bundle
        if let cached = RoutesCatalogLoader.loadCache(), Self.isNewer(cached, than: bundled) {
            _routes = cached.routes
            _dataUpdated = cached.dataUpdated
            _source = .cache
        }
    }

    func apply(payload: RoutesCatalogPayload, source: TimetableDataSource) {
        lock.lock()
        _routes = payload.routes
        _dataUpdated = payload.dataUpdated
        _source = source
        lock.unlock()
    }

    private static func isNewer(_ candidate: RoutesCatalogPayload, than baseline: RoutesCatalogPayload) -> Bool {
        guard let a = candidate.dataUpdated, let b = baseline.dataUpdated else {
            return candidate.dataUpdated != nil
        }
        return a > b
    }
}

@MainActor
@Observable
final class TimetableCatalogStore {
    static let shared = TimetableCatalogStore()

    private(set) var routes: [Route] = []
    private(set) var dataUpdated: String?
    private(set) var source: TimetableDataSource = .bundle
    private(set) var isRefreshing = false
    private(set) var lastRefreshError: String?

    private var hasAttemptedAutoRefresh = false

    init() {
        syncFromSnapshot()
    }

    private func syncFromSnapshot() {
        let snap = CatalogSnapshot.shared
        routes = snap.routes
        dataUpdated = snap.dataUpdated
        source = snap.source
    }

    func refreshFromNetworkIfNeeded(isOnline: Bool) async {
        guard isOnline, !hasAttemptedAutoRefresh else { return }
        hasAttemptedAutoRefresh = true
        await refreshFromNetwork()
    }

    func refreshFromNetwork() async {
        guard let url = TimetableFeedURL.url else { return }
        isRefreshing = true
        lastRefreshError = nil
        defer { isRefreshing = false }

        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 25

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200 ... 299).contains(http.statusCode) else {
                lastRefreshError = "HTTP"
                return
            }
            let payload = try RoutesCatalogLoader.decode(data)
            guard !payload.routes.isEmpty else {
                lastRefreshError = "empty"
                return
            }
            let bundled = RoutesCatalogLoader.loadBundled()
            let snap = CatalogSnapshot.shared
            if Self.isNewer(payload, than: bundled) || snap.source == .bundle {
                CatalogSnapshot.shared.apply(payload: payload, source: .network)
                RoutesCatalogLoader.saveCache(data)
                syncFromSnapshot()
            }
        } catch {
            lastRefreshError = error.localizedDescription
        }
    }

    private static func isNewer(_ candidate: RoutesCatalogPayload, than baseline: RoutesCatalogPayload) -> Bool {
        guard let a = candidate.dataUpdated, let b = baseline.dataUpdated else {
            return candidate.dataUpdated != nil
        }
        return a > b
    }
}
