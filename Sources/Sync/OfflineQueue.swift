import Foundation

final class OfflineQueue {
    static let shared = OfflineQueue()

    private let opStore = PendingOpStore(db: DatabaseManager.shared.pool)
    private let api = GoogleAPIClient()
    private var isProcessing = false

    func enqueue(_ op: PendingOp) {
        try? opStore.save(op)
        processQueue()
    }

    func processQueue() {
        guard !isProcessing else { return }
        isProcessing = true

        Task {
            defer { isProcessing = false }
            let ops = (try? opStore.all()) ?? []
            for op in ops {
                do {
                    try await execute(op)
                    try? opStore.delete(op.id)
                } catch {
                    try? opStore.incrementRetry(op.id, error: error.localizedDescription)
                    if op.retryCount >= 5 { continue }
                    try? await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(op.retryCount))) * 1_000_000_000)
                }
            }
        }
    }

    private func execute(_ op: PendingOp) async throws {
        guard let type = PendingOp.OpType(rawValue: op.opType) else { return }

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
    }
}
