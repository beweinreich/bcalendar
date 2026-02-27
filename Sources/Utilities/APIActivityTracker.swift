import Foundation

final class APIActivityTracker {
    static let shared = APIActivityTracker()

    private let queue = DispatchQueue(label: "APIActivityTracker")
    private var activeCount = 0

    var isActive: Bool { queue.sync { activeCount > 0 } }

    func begin() {
        queue.async {
            self.activeCount += 1
            self.notify()
        }
    }

    func end() {
        queue.async {
            self.activeCount = max(0, self.activeCount - 1)
            self.notify()
        }
    }

    private func notify() {
        let active = activeCount > 0
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .apiActivityChanged, object: nil,
                                            userInfo: ["active": active])
        }
    }
}

extension Notification.Name {
    static let apiActivityChanged = Notification.Name("apiActivityChanged")
}
