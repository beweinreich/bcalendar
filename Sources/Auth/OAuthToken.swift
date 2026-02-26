import Foundation

struct OAuthToken: Codable {
    var accessToken: String
    var refreshToken: String
    var expiresAt: Date
    var tokenType: String

    var isExpired: Bool {
        Date() >= expiresAt.addingTimeInterval(-60)
    }

    static func save(_ token: OAuthToken, accountId: String) throws {
        let data = try JSONEncoder().encode(token)
        try KeychainHelper.save(account: accountId, data: data)
    }

    static func load(accountId: String) -> OAuthToken? {
        guard let data = KeychainHelper.load(account: accountId) else { return nil }
        return try? JSONDecoder().decode(OAuthToken.self, from: data)
    }

    static func delete(accountId: String) {
        KeychainHelper.delete(account: accountId)
    }
}
