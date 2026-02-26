import GRDB

struct AccountStore {
    let db: DatabasePool

    func all() throws -> [Account] {
        try db.read { db in try Account.fetchAll(db) }
    }

    func find(_ id: String) throws -> Account? {
        try db.read { db in try Account.fetchOne(db, key: id) }
    }

    func save(_ account: Account) throws {
        try db.write { db in try account.save(db) }
    }

    func delete(_ id: String) throws {
        try db.write { db in _ = try Account.deleteOne(db, key: id) }
    }
}
