import Foundation
import GRDB

struct Event: Codable, FetchableRecord, PersistableRecord, Identifiable {
    static let databaseTableName = "event"

    var id: String
    var accountId: String
    var calendarId: String
    var iCalUID: String?
    var etag: String?
    var status: String
    var summary: String
    var location: String?
    var eventDescription: String?
    var start: Date
    var end: Date
    var allDay: Bool
    var timeZone: String?
    var recurrence: String?
    var recurringEventId: String?
    var originalStartTime: Date?
    var organizerEmail: String?
    var organizerName: String?
    var attendeesJSON: String?
    var remindersJSON: String?
    var rawJSON: String?
    var updated: Date
    var dirtyState: Int
    var deletedFlag: Bool

    enum DirtyState: Int, Codable {
        case clean = 0, created = 1, modified = 2, deleted = 3
    }

    init(id: String = UUID().uuidString, accountId: String, calendarId: String,
         summary: String, start: Date, end: Date, allDay: Bool = false) {
        self.id = id
        self.accountId = accountId
        self.calendarId = calendarId
        self.status = "confirmed"
        self.summary = summary
        self.start = start
        self.end = end
        self.allDay = allDay
        self.updated = Date()
        self.dirtyState = DirtyState.clean.rawValue
        self.deletedFlag = false
    }
}
