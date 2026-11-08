import Network
import Observation

/// Стан мережі для офлайн-підказок (карти й зовнішні посилання потребують інтернету).
@Observable
final class NetworkMonitor {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "capri.network")

    private(set) var isOnline = true

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isOnline = path.status == .satisfied
            }
        }
        monitor.start(queue: queue)
    }

    deinit { monitor.cancel() }
}
