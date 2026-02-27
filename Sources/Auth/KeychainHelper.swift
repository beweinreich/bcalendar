import Foundation
import Security

enum KeychainHelper {
    private static let service = "com.bcalendar.oauth"

    static func save(account: String, data: Data) throws {
        #if DEBUG
        try FileTokenStore.save(service: service, account: account, data: data)
        #else
        try keychainSave(account: account, data: data)
        #endif
    }

    static func load(account: String) -> Data? {
        #if DEBUG
        return FileTokenStore.load(service: service, account: account)
        #else
        return keychainLoad(account: account)
        #endif
    }

    static func delete(account: String) {
        #if DEBUG
        FileTokenStore.delete(service: service, account: account)
        #else
        keychainDelete(account: account)
        #endif
    }

    // MARK: - Keychain (Release)

    private static var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
        ]
    }

    private static func keychainSave(account: String, data: Data) throws {
        var query = baseQuery
        query[kSecAttrAccount as String] = account
        SecItemDelete(query as CFDictionary)

        var addQuery = query
        addQuery[kSecValueData as String] = data
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
        }
    }

    private static func keychainLoad(account: String) -> Data? {
        var query = baseQuery
        query[kSecAttrAccount as String] = account
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else { return nil }
        return result as? Data
    }

    private static func keychainDelete(account: String) {
        var query = baseQuery
        query[kSecAttrAccount as String] = account
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - File-based store for DEBUG builds (avoids Keychain prompts)

private enum FileTokenStore {
    private static var directory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("BCalendar/tokens", isDirectory: true)
    }

    private static func fileURL(service: String, account: String) -> URL {
        directory.appendingPathComponent("\(service).\(account)")
    }

    static func save(service: String, account: String, data: Data) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: fileURL(service: service, account: account))
    }

    static func load(service: String, account: String) -> Data? {
        try? Data(contentsOf: fileURL(service: service, account: account))
    }

    static func delete(service: String, account: String) {
        try? FileManager.default.removeItem(at: fileURL(service: service, account: account))
    }
}
