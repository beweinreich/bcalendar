import Foundation
import Network

final class NetworkMonitor {
    static let shared = NetworkMonitor()

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")

    private(set) var isReachable = true

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let reachable = path.status == .satisfied
            DispatchQueue.main.async {
                let wasReachable = self?.isReachable ?? false
                self?.isReachable = reachable
                if !wasReachable && reachable {
                    NotificationCenter.default.post(name: .networkBecameReachable, object: nil)
                }
            }
        }
        monitor.start(queue: queue)
    }
}

extension Notification.Name {
    static let networkBecameReachable = Notification.Name("networkBecameReachable")
}
