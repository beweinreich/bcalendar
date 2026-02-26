import Foundation
import GRDB

struct Account: Codable, FetchableRecord, PersistableRecord, Identifiable {
    static let databaseTableName = "account"

    var id: String
    var email: String
    var displayName: String
    var createdAt: Date

    init(id: String = UUID().uuidString, email: String, displayName: String, createdAt: Date = Date()) {
        self.id = id
        self.email = email
        self.displayName = displayName
        self.createdAt = createdAt
    }
}
