import GRDB

enum Migrations {
    static func run(_ db: DatabasePool) throws {
        var migrator = DatabaseMigrator()

        migrator.registerMigration("v1") { db in
            try db.create(table: "account") { t in
                t.column("id", .text).primaryKey()
                t.column("email", .text).notNull()
                t.column("displayName", .text).notNull()
                t.column("createdAt", .datetime).notNull()
            }

            try db.create(table: "calendar") { t in
                t.column("id", .text).primaryKey()
                t.column("accountId", .text).notNull().references("account", onDelete: .cascade)
                t.column("summary", .text).notNull()
                t.column("colorHex", .text).notNull()
                t.column("accessRole", .text).notNull()
                t.column("selected", .boolean).notNull().defaults(to: true)
                t.column("syncToken", .text)
                t.column("timeZone", .text)
                t.column("updatedAt", .datetime).notNull()
            }

            try db.create(table: "event") { t in
                t.column("id", .text).primaryKey()
                t.column("accountId", .text).notNull()
                t.column("calendarId", .text).notNull().references("calendar", onDelete: .cascade)
                t.column("iCalUID", .text)
                t.column("etag", .text)
                t.column("status", .text).notNull()
                t.column("summary", .text).notNull()
                t.column("location", .text)
                t.column("eventDescription", .text)
                t.column("start", .datetime).notNull()
                t.column("end", .datetime).notNull()
                t.column("allDay", .boolean).notNull().defaults(to: false)
                t.column("timeZone", .text)
                t.column("recurrence", .text)
                t.column("recurringEventId", .text)
                t.column("originalStartTime", .datetime)
                t.column("organizerEmail", .text)
                t.column("organizerName", .text)
                t.column("attendeesJSON", .text)
                t.column("remindersJSON", .text)
                t.column("rawJSON", .text)
                t.column("updated", .datetime).notNull()
                t.column("dirtyState", .integer).notNull().defaults(to: 0)
                t.column("deletedFlag", .boolean).notNull().defaults(to: false)
            }

            try db.create(index: "event_calendar_range",
                          on: "event", columns: ["calendarId", "start", "end"])
            try db.create(index: "event_recurring",
                          on: "event", columns: ["recurringEventId"])
            try db.create(index: "event_account",
                          on: "event", columns: ["accountId"])
            try db.create(index: "event_dirty",
                          on: "event", columns: ["dirtyState"])

            try db.create(table: "pendingOp") { t in
                t.column("id", .text).primaryKey()
                t.column("accountId", .text).notNull()
                t.column("calendarId", .text).notNull()
                t.column("eventId", .text)
                t.column("opType", .text).notNull()
                t.column("payloadJSON", .text).notNull()
                t.column("createdAt", .datetime).notNull()
                t.column("retryCount", .integer).notNull().defaults(to: 0)
                t.column("lastError", .text)
            }
        }

        migrator.registerMigration("v2_add_calendar_isPrimary") { db in
            try db.alter(table: "calendar") { t in
                t.add(column: "isPrimary", .boolean).notNull().defaults(to: false)
            }
        }

        try migrator.migrate(db)
    }
}
