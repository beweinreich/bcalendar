import Foundation
import AppKit

final class OfflineQueue {
    static let shared = OfflineQueue()

    private let opStore = PendingOpStore(db: DatabaseManager.shared.pool)
    private let api = GoogleAPIClient()
    private var isProcessing = false

    init() {
        _ = NetworkMonitor.shared
        NotificationCenter.default.addObserver(
            self, selector: #selector(networkBecameReachable),
            name: .networkBecameReachable, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(appBecameActive),
            name: NSApplication.didBecomeActiveNotification, object: nil
        )
    }

    @objc private func appBecameActive() {
        processQueue()
    }

    func enqueue(_ op: PendingOp) {
        try? opStore.save(op)
        NotificationCenter.default.post(name: .offlineQueueChanged, object: nil)
        if NetworkMonitor.shared.isReachable {
            processQueue()
        }
    }

    func pendingOps() -> [PendingOp] {
        (try? opStore.all()) ?? []
    }

    func removeOp(id: String) {
        try? opStore.delete(id)
        NotificationCenter.default.post(name: .offlineQueueChanged, object: nil)
    }

    @objc private func networkBecameReachable() {
        processQueue()
    }

    func processQueue() {
        guard !isProcessing else { return }
        guard NetworkMonitor.shared.isReachable else { return }
        isProcessing = true
        APIActivityTracker.shared.begin()

        Task(priority: .userInitiated) {
            defer {
                isProcessing = false
                APIActivityTracker.shared.end()
            }
            let ops = (try? opStore.all()) ?? []
            for op in ops {
                do {
                    try await execute(op)
                    try? opStore.delete(op.id)
                    NotificationCenter.default.post(name: .offlineQueueChanged, object: nil)
                } catch {
                    try? opStore.incrementRetry(op.id, error: error.localizedDescription)
                    if op.retryCount >= 5 {
                        try? opStore.delete(op.id)
                        NotificationCenter.default.post(name: .offlineQueueChanged, object: nil)
                        continue
                    }
                    try? await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(op.retryCount))) * 1_000_000_000)
                }
            }
        }
    }

    private func execute(_ op: PendingOp) async throws {
        guard let type = PendingOp.OpType(rawValue: op.opType) else { return }

        let (method, path): (String, String) = {
            let escapedCalId = op.calendarId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)!
            switch type {
            case .create: return ("POST", "/calendars/\(escapedCalId)/events")
            case .update, .rsvp:
                let escapedEvtId = (op.eventId ?? "").addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)!
                return (type == .update ? "PUT" : "PATCH", "/calendars/\(escapedCalId)/events/\(escapedEvtId)")
            case .delete:
                let escapedEvtId = (op.eventId ?? "").addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)!
                return ("DELETE", "/calendars/\(escapedCalId)/events/\(escapedEvtId)")
            }
        }()

        do {
            switch type {
            case .create:
                let body = try JSONSerialization.jsonObject(with: op.payloadJSON.data(using: .utf8)!) as! [String: Any]
                let result = try await api.insertEvent(accountId: op.accountId, calendarId: op.calendarId, body: body)
                if let newId = result["id"] as? String, let eventId = op.eventId {
                    let etag = result["etag"] as? String
                    try EventStore(db: DatabaseManager.shared.pool).clearDirty(eventId, etag: etag)
                }

            case .update:
                guard let eventId = op.eventId else { return }
                let body = try JSONSerialization.jsonObject(with: op.payloadJSON.data(using: .utf8)!) as! [String: Any]
                let result = try await api.updateEvent(accountId: op.accountId, calendarId: op.calendarId,
                                                        eventId: eventId, body: body)
                let etag = result["etag"] as? String
                try EventStore(db: DatabaseManager.shared.pool).clearDirty(eventId, etag: etag)

            case .delete:
                guard let eventId = op.eventId else { return }
                try await api.deleteEvent(accountId: op.accountId, calendarId: op.calendarId, eventId: eventId)
                try EventStore(db: DatabaseManager.shared.pool).delete(eventId)

            case .rsvp:
                guard let eventId = op.eventId else { return }
                let body = try JSONSerialization.jsonObject(with: op.payloadJSON.data(using: .utf8)!) as! [String: Any]
                _ = try await api.patchEvent(accountId: op.accountId, calendarId: op.calendarId,
                                              eventId: eventId, body: body, sendUpdates: "all")
            }
        } catch {
            if !(error is APIError) {
                let operation = type.rawValue
                APIRequestLogger.shared.log(operation: operation, method: method, path: path,
                                            statusCode: 0, errorMessage: error.localizedDescription)
            }
            throw error
        }
    }
}
