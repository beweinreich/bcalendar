import Foundation

struct CalendarListSync {
    let api = GoogleAPIClient()
    let calendarStore = CalendarStore(db: DatabaseManager.shared.pool)

    func sync(accountId: String) async throws {
        let items = try await api.fetchCalendarList(accountId: accountId)
        let existing = try calendarStore.forAccount(accountId)
        let existingIds = Set(existing.map(\.id))
        var remoteIds = Set<String>()

        for item in items {
            let id = item["id"] as? String ?? UUID().uuidString
            remoteIds.insert(id)
            let wasSelected = existing.first(where: { $0.id == id })?.selected ?? true

            let cal = GCalendar(
                id: id,
                accountId: accountId,
                summary: item["summary"] as? String ?? "Untitled",
                colorHex: item["backgroundColor"] as? String ?? "#4285F4",
                accessRole: item["accessRole"] as? String ?? "reader",
                selected: wasSelected,
                isPrimary: item["primary"] as? Bool ?? false,
                timeZone: item["timeZone"] as? String
            )
            try calendarStore.save(cal)
        }

        let eStore = EventStore(db: DatabaseManager.shared.pool)
        for id in existingIds.subtracting(remoteIds) {
            try eStore.deleteForCalendar(id)
            try calendarStore.delete(id)
        }
    }
}
