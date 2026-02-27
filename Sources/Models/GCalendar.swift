import Foundation
import GRDB

struct GCalendar: Codable, FetchableRecord, PersistableRecord, Identifiable {
    static let databaseTableName = "calendar"

    var id: String
    var accountId: String
    var summary: String
    var colorHex: String
    var accessRole: String
    var selected: Bool
    var isPrimary: Bool
    var syncToken: String?
    var timeZone: String?
    var updatedAt: Date

    var isReadOnly: Bool {
        accessRole == "reader" || accessRole == "freeBusyReader"
    }

    init(id: String, accountId: String, summary: String, colorHex: String = "#4285F4",
         accessRole: String = "owner", selected: Bool = true,          isPrimary: Bool = false, timeZone: String? = nil) {
        self.id = id
        self.accountId = accountId
        self.summary = summary
        self.colorHex = colorHex
        self.accessRole = accessRole
        self.selected = selected
        self.isPrimary = isPrimary
        self.timeZone = timeZone
        self.updatedAt = Date()
    }
}
