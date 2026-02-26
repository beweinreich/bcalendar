import Foundation
import GRDB

final class DatabaseManager {
    static let shared = DatabaseManager()
    let pool: DatabasePool

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dbDir = appSupport.appendingPathComponent("BCalendar", isDirectory: true)
        try! FileManager.default.createDirectory(at: dbDir, withIntermediateDirectories: true)
        let dbPath = dbDir.appendingPathComponent("db.sqlite").path

        var config = Configuration()
        config.maximumReaderCount = 4

        pool = try! DatabasePool(path: dbPath, configuration: config)
        try! Migrations.run(pool)
    }
}
