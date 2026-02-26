import Foundation
import AppKit

final class SyncScheduler {
    static let shared = SyncScheduler()

    private var timer: Timer?

    func start() {
        triggerSync()

        NotificationCenter.default.addObserver(
            self, selector: #selector(appBecameActive),
            name: NSApplication.didBecomeActiveNotification, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(manualRefresh),
            name: .syncRequested, object: nil
        )

        timer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            self?.triggerSync()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    @objc private func appBecameActive() {
        triggerSync()
    }

    @objc private func manualRefresh() {
        triggerSync()
    }

    private func triggerSync() {
        Task {
            await SyncEngine.shared.syncAll()
        }
    }
}
