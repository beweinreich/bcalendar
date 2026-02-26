import Foundation
import GRDB

struct PendingOp: Codable, FetchableRecord, PersistableRecord, Identifiable {
    static let databaseTableName = "pendingOp"

    var id: String
    var accountId: String
    var calendarId: String
    var eventId: String?
    var opType: String
    var payloadJSON: String
    var createdAt: Date
    var retryCount: Int
    var lastError: String?

    enum OpType: String, Codable {
        case create, update, delete, rsvp
    }

    init(accountId: String, calendarId: String, eventId: String? = nil,
         opType: OpType, payloadJSON: String) {
        self.id = UUID().uuidString
        self.accountId = accountId
        self.calendarId = calendarId
        self.eventId = eventId
        self.opType = opType.rawValue
        self.payloadJSON = payloadJSON
        self.createdAt = Date()
        self.retryCount = 0
    }
}
