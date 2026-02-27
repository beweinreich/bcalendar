import GRDB

struct CalendarStore {
    let db: DatabasePool

    func all() throws -> [GCalendar] {
        try db.read { db in try GCalendar.fetchAll(db) }
    }

    func forAccount(_ accountId: String) throws -> [GCalendar] {
        let cals = try db.read { db in
            try GCalendar.filter(Column("accountId") == accountId).fetchAll(db)
        }
        return cals.sorted { $0.isPrimary && !$1.isPrimary }
    }

    func selected() throws -> [GCalendar] {
        try db.read { db in
            try GCalendar.filter(Column("selected") == true).fetchAll(db)
        }
    }

    func save(_ calendar: GCalendar) throws {
        try db.write { db in try calendar.save(db) }
    }

    func toggleSelected(_ id: String) throws {
        try db.write { db in
            if var cal = try GCalendar.fetchOne(db, key: id) {
                cal.selected.toggle()
                try cal.update(db)
            }
        }
    }

    func updateSyncToken(_ id: String, token: String?) throws {
        try db.write { db in
            if var cal = try GCalendar.fetchOne(db, key: id) {
                cal.syncToken = token
                try cal.update(db)
            }
        }
    }

    func delete(_ id: String) throws {
        try db.write { db in _ = try GCalendar.deleteOne(db, key: id) }
    }

    func deleteForAccount(_ accountId: String) throws {
        try db.write { db in
            _ = try GCalendar.filter(Column("accountId") == accountId).deleteAll(db)
        }
    }
}
