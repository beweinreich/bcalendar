import Foundation

actor SyncEngine {
    static let shared = SyncEngine()

    private let calendarListSync = CalendarListSync()
    private let eventSync = EventSync()
    private let accountStore = AccountStore(db: DatabaseManager.shared.pool)
    private let calendarStore = CalendarStore(db: DatabaseManager.shared.pool)

    private(set) var isSyncing = false

    func syncAll() async {
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }

        guard let accounts = try? accountStore.all() else { return }

        for account in accounts {
            guard OAuthToken.load(accountId: account.id) != nil else { continue }

            do {
                try await calendarListSync.sync(accountId: account.id)
                let calendars = try calendarStore.forAccount(account.id).filter(\.selected)

                for calendar in calendars {
                    if let syncToken = calendar.syncToken {
                        try await eventSync.incrementalSync(
                            accountId: account.id, calendarId: calendar.id, syncToken: syncToken
                        )
                    } else {
                        try await eventSync.initialSync(accountId: account.id, calendarId: calendar.id)
                    }
                }
            } catch {
                print("Sync error for \(account.email): \(error)")
            }
        }

        await MainActor.run {
            NotificationCenter.default.post(name: .calendarsChanged, object: nil)
            NotificationCenter.default.post(name: .eventsChanged, object: nil)
        }
    }

    func syncCalendar(accountId: String, calendarId: String) async {
        guard let calendar = try? calendarStore.forAccount(accountId).first(where: { $0.id == calendarId }) else { return }

        do {
            if let syncToken = calendar.syncToken {
                try await eventSync.incrementalSync(accountId: accountId, calendarId: calendarId, syncToken: syncToken)
            } else {
                try await eventSync.initialSync(accountId: accountId, calendarId: calendarId)
            }
        } catch {
            print("Sync error for calendar \(calendarId): \(error)")
        }

        await MainActor.run {
            NotificationCenter.default.post(name: .eventsChanged, object: nil)
        }
    }
}
