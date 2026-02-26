import GRDB

struct PendingOpStore {
    let db: DatabasePool

    func all() throws -> [PendingOp] {
        try db.read { db in
            try PendingOp.order(Column("createdAt")).fetchAll(db)
        }
    }

    func save(_ op: PendingOp) throws {
        try db.write { db in try op.insert(db) }
    }

    func delete(_ id: String) throws {
        try db.write { db in _ = try PendingOp.deleteOne(db, key: id) }
    }

    func incrementRetry(_ id: String, error: String) throws {
        try db.write { db in
            if var op = try PendingOp.fetchOne(db, key: id) {
                op.retryCount += 1
                op.lastError = error
                try op.update(db)
            }
        }
    }
}
