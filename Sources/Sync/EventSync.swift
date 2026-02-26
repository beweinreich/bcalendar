import Foundation

struct EventSync {
    let api = GoogleAPIClient()
    let eventStore = EventStore(db: DatabaseManager.shared.pool)
    let calendarStore = CalendarStore(db: DatabaseManager.shared.pool)

    func initialSync(accountId: String, calendarId: String) async throws {
        let cal = Calendar.current
        let now = Date()
        let timeMin = cal.date(byAdding: .month, value: -12, to: now)!
        let timeMax = cal.date(byAdding: .month, value: 12, to: now)!

        var pageToken: String? = nil
        var syncToken: String? = nil

        repeat {
            let result = try await api.fetchEvents(
                accountId: accountId, calendarId: calendarId,
                timeMin: timeMin, timeMax: timeMax, pageToken: pageToken
            )
            for item in result.events {
                let event = parseEvent(item, accountId: accountId, calendarId: calendarId)
                try eventStore.upsert(event)
            }
            pageToken = result.nextPageToken
            syncToken = result.nextSyncToken
        } while pageToken != nil

        if let syncToken = syncToken {
            try calendarStore.updateSyncToken(calendarId, token: syncToken)
        }
    }

    func incrementalSync(accountId: String, calendarId: String, syncToken: String) async throws {
        var pageToken: String? = nil
        var newSyncToken: String? = nil

        do {
            repeat {
                let result = try await api.fetchEvents(
                    accountId: accountId, calendarId: calendarId,
                    syncToken: syncToken, pageToken: pageToken
                )
                for item in result.events {
                    let status = item["status"] as? String ?? ""
                    let eventId = item["id"] as? String ?? ""

                    if status == "cancelled" {
                        try eventStore.delete(eventId)
                    } else {
                        let event = parseEvent(item, accountId: accountId, calendarId: calendarId)
                        try eventStore.upsert(event)
                    }
                }
                pageToken = result.nextPageToken
                newSyncToken = result.nextSyncToken
            } while pageToken != nil

            if let newSyncToken = newSyncToken {
                try calendarStore.updateSyncToken(calendarId, token: newSyncToken)
            }
        } catch let error as APIError where error.is410Gone {
            try calendarStore.updateSyncToken(calendarId, token: nil)
            try eventStore.deleteForCalendar(calendarId)
            try await initialSync(accountId: accountId, calendarId: calendarId)
        }
    }

    private func parseEvent(_ json: [String: Any], accountId: String, calendarId: String) -> Event {
        let id = json["id"] as? String ?? UUID().uuidString

        let (start, end, allDay, tz) = parseDates(json)

        var event = Event(id: id, accountId: accountId, calendarId: calendarId,
                          summary: json["summary"] as? String ?? "(No title)",
                          start: start, end: end, allDay: allDay)
        event.iCalUID = json["iCalUID"] as? String
        event.etag = json["etag"] as? String
        event.status = json["status"] as? String ?? "confirmed"
        event.location = json["location"] as? String
        event.eventDescription = json["description"] as? String
        event.timeZone = tz
        event.recurringEventId = json["recurringEventId"] as? String

        if let recurrence = json["recurrence"] as? [String] {
            event.recurrence = recurrence.joined(separator: "\n")
        }

        if let origStart = json["originalStartTime"] as? [String: Any] {
            event.originalStartTime = parseDateTime(origStart)
        }

        if let organizer = json["organizer"] as? [String: Any] {
            event.organizerEmail = organizer["email"] as? String
            event.organizerName = organizer["displayName"] as? String
        }

        if let attendees = json["attendees"] as? [[String: Any]] {
            event.attendeesJSON = try? String(data: JSONSerialization.data(withJSONObject: attendees), encoding: .utf8)
        }

        if let reminders = json["reminders"] as? [String: Any] {
            event.remindersJSON = try? String(data: JSONSerialization.data(withJSONObject: reminders), encoding: .utf8)
        }

        event.rawJSON = try? String(data: JSONSerialization.data(withJSONObject: json), encoding: .utf8)

        if let updatedStr = json["updated"] as? String {
            let fmt = ISO8601DateFormatter()
            fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            event.updated = fmt.date(from: updatedStr) ?? Date()
        }

        return event
    }

    private func parseDates(_ json: [String: Any]) -> (start: Date, end: Date, allDay: Bool, tz: String?) {
        let startObj = json["start"] as? [String: Any] ?? [:]
        let endObj = json["end"] as? [String: Any] ?? [:]

        if let dateStr = startObj["date"] as? String {
            let fmt = DateFormatter()
            fmt.dateFormat = "yyyy-MM-dd"
            let start = fmt.date(from: dateStr) ?? Date()
            let endStr = endObj["date"] as? String ?? dateStr
            let end = fmt.date(from: endStr) ?? start
            return (start, end, true, nil)
        }

        let tz = startObj["timeZone"] as? String
        let start = parseDateTime(startObj)
        let end = parseDateTime(endObj)
        return (start, end, false, tz)
    }

    private func parseDateTime(_ obj: [String: Any]) -> Date {
        guard let str = obj["dateTime"] as? String ?? obj["date"] as? String else { return Date() }
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = fmt.date(from: str) { return d }
        fmt.formatOptions = [.withInternetDateTime]
        return fmt.date(from: str) ?? Date()
    }
}
