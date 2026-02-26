import Foundation
import GRDB

struct EventStore {
    let db: DatabasePool

    func events(in calendarIds: [String], from startDate: Date, to endDate: Date) throws -> [Event] {
        try db.read { db in
            try Event
                .filter(calendarIds.contains(Column("calendarId")))
                .filter(Column("start") < endDate)
                .filter(Column("end") > startDate)
                .filter(Column("deletedFlag") == false)
                .order(Column("start"))
                .fetchAll(db)
        }
    }

    func find(_ id: String) throws -> Event? {
        try db.read { db in try Event.fetchOne(db, key: id) }
    }

    func save(_ event: Event) throws {
        try db.write { db in try event.save(db) }
    }

    func upsert(_ event: Event) throws {
        try db.write { db in
            if let existing = try Event.fetchOne(db, key: event.id) {
                if existing.dirtyState == Event.DirtyState.clean.rawValue {
                    try event.update(db)
                }
            } else {
                try event.insert(db)
            }
        }
    }

    func delete(_ id: String) throws {
        try db.write { db in _ = try Event.deleteOne(db, key: id) }
    }

    func markDeleted(_ id: String) throws {
        try db.write { db in
            if var event = try Event.fetchOne(db, key: id) {
                event.deletedFlag = true
                event.dirtyState = Event.DirtyState.deleted.rawValue
                try event.update(db)
            }
        }
    }

    func dirtyEvents() throws -> [Event] {
        try db.read { db in
            try Event.filter(Column("dirtyState") != 0).fetchAll(db)
        }
    }

    func clearDirty(_ id: String, etag: String?) throws {
        try db.write { db in
            if var event = try Event.fetchOne(db, key: id) {
                event.dirtyState = Event.DirtyState.clean.rawValue
                event.etag = etag
                try event.update(db)
            }
        }
    }

    func deleteForCalendar(_ calendarId: String) throws {
        try db.write { db in
            _ = try Event.filter(Column("calendarId") == calendarId).deleteAll(db)
        }
    }
}
