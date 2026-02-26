import Foundation
import AppKit

enum EventActions {
    static func createEvent(data: EventEditorData, accountId: String) {
        var event = Event(accountId: accountId, calendarId: data.calendarId,
                          summary: data.title, start: data.startDate, end: data.endDate,
                          allDay: data.isAllDay)
        event.location = data.location
        event.eventDescription = data.notes
        event.recurrence = data.recurrenceRule.isEmpty ? nil : data.recurrenceRule
        event.dirtyState = Event.DirtyState.created.rawValue

        if data.reminderMinutes > 0 {
            let reminders: [String: Any] = [
                "useDefault": false,
                "overrides": [["method": "popup", "minutes": data.reminderMinutes]]
            ]
            event.remindersJSON = try? String(data: JSONSerialization.data(withJSONObject: reminders), encoding: .utf8)
        }

        if !data.attendees.isEmpty {
            event.attendeesJSON = AttendeeHelper.toJSON(data.attendees)
        }

        try? EventStore(db: DatabaseManager.shared.pool).save(event)

        let body = eventToGoogleJSON(event)
        let op = PendingOp(accountId: accountId, calendarId: data.calendarId,
                           eventId: event.id, opType: .create,
                           payloadJSON: jsonString(body))
        OfflineQueue.shared.enqueue(op)

        NotificationCenter.default.post(name: .eventsChanged, object: nil)
    }

    static func updateEvent(_ event: Event, data: EventEditorData) {
        var updated = event
        updated.summary = data.title
        updated.location = data.location
        updated.eventDescription = data.notes
        updated.start = data.startDate
        updated.end = data.endDate
        updated.allDay = data.isAllDay
        updated.calendarId = data.calendarId
        updated.recurrence = data.recurrenceRule.isEmpty ? nil : data.recurrenceRule
        updated.dirtyState = Event.DirtyState.modified.rawValue
        updated.updated = Date()

        if data.reminderMinutes > 0 {
            let reminders: [String: Any] = [
                "useDefault": false,
                "overrides": [["method": "popup", "minutes": data.reminderMinutes]]
            ]
            updated.remindersJSON = try? String(data: JSONSerialization.data(withJSONObject: reminders), encoding: .utf8)
        }

        try? EventStore(db: DatabaseManager.shared.pool).save(updated)

        let body = eventToGoogleJSON(updated)
        let op = PendingOp(accountId: event.accountId, calendarId: data.calendarId,
                           eventId: event.id, opType: .update,
                           payloadJSON: jsonString(body))
        OfflineQueue.shared.enqueue(op)

        NotificationCenter.default.post(name: .eventsChanged, object: nil)
    }

    static func moveEvent(_ eventId: String, newStart: Date, newEnd: Date) {
        let store = EventStore(db: DatabaseManager.shared.pool)
        guard var event = try? store.find(eventId) else { return }

        event.start = newStart
        event.end = newEnd
        event.dirtyState = Event.DirtyState.modified.rawValue
        event.updated = Date()
        try? store.save(event)

        let body = eventToGoogleJSON(event)
        let op = PendingOp(accountId: event.accountId, calendarId: event.calendarId,
                           eventId: event.id, opType: .update,
                           payloadJSON: jsonString(body))
        OfflineQueue.shared.enqueue(op)

        NotificationCenter.default.post(name: .eventsChanged, object: nil)
    }

    static func deleteEvent(_ event: Event) {
        try? EventStore(db: DatabaseManager.shared.pool).markDeleted(event.id)

        let op = PendingOp(accountId: event.accountId, calendarId: event.calendarId,
                           eventId: event.id, opType: .delete, payloadJSON: "{}")
        OfflineQueue.shared.enqueue(op)

        NotificationCenter.default.post(name: .eventsChanged, object: nil)
    }

    static func deleteRecurring(_ event: Event, scope: RecurrenceEditScope) {
        let store = EventStore(db: DatabaseManager.shared.pool)
        switch scope {
        case .thisEvent:
            deleteEvent(event)
        case .thisAndFuture:
            if let masterEventId = event.recurringEventId ?? Optional(event.id) {
                let allEvents = (try? store.events(in: [event.calendarId],
                    from: event.start, to: Date.distantFuture)) ?? []
                for e in allEvents where (e.recurringEventId == masterEventId || e.id == masterEventId)
                    && e.start >= event.start {
                    deleteEvent(e)
                }
            }
        case .allEvents:
            let masterEventId = event.recurringEventId ?? event.id
            if let master = try? store.find(masterEventId) {
                deleteEvent(master)
            }
            let allEvents = (try? store.events(in: [event.calendarId],
                from: Date.distantPast, to: Date.distantFuture)) ?? []
            for e in allEvents where e.recurringEventId == masterEventId {
                try? store.delete(e.id)
            }
            NotificationCenter.default.post(name: .eventsChanged, object: nil)
        }
    }

    static func updateRecurring(_ event: Event, data: EventEditorData, scope: RecurrenceEditScope) {
        let store = EventStore(db: DatabaseManager.shared.pool)
        switch scope {
        case .thisEvent:
            var exception = event
            exception.recurringEventId = event.recurringEventId ?? event.id
            exception.originalStartTime = event.start
            exception.recurrence = nil
            exception.summary = data.title
            exception.location = data.location
            exception.eventDescription = data.notes
            exception.start = data.startDate
            exception.end = data.endDate
            exception.allDay = data.isAllDay
            exception.dirtyState = Event.DirtyState.modified.rawValue
            exception.updated = Date()
            try? store.save(exception)

            let body = eventToGoogleJSON(exception)
            let op = PendingOp(accountId: event.accountId, calendarId: data.calendarId,
                               eventId: exception.id, opType: .update, payloadJSON: jsonString(body))
            OfflineQueue.shared.enqueue(op)
            NotificationCenter.default.post(name: .eventsChanged, object: nil)

        case .thisAndFuture:
            updateEvent(event, data: data)

        case .allEvents:
            let masterEventId = event.recurringEventId ?? event.id
            if var master = try? store.find(masterEventId) {
                master.summary = data.title
                master.location = data.location
                master.eventDescription = data.notes
                master.recurrence = data.recurrenceRule.isEmpty ? nil : data.recurrenceRule
                master.dirtyState = Event.DirtyState.modified.rawValue
                master.updated = Date()
                try? store.save(master)

                let body = eventToGoogleJSON(master)
                let op = PendingOp(accountId: master.accountId, calendarId: master.calendarId,
                                   eventId: master.id, opType: .update, payloadJSON: jsonString(body))
                OfflineQueue.shared.enqueue(op)
            }
            NotificationCenter.default.post(name: .eventsChanged, object: nil)
        }
    }

    // MARK: - Helpers

    static func eventToGoogleJSON(_ event: Event) -> [String: Any] {
        var body: [String: Any] = [
            "summary": event.summary,
        ]

        if event.allDay {
            let fmt = DateFormatter()
            fmt.dateFormat = "yyyy-MM-dd"
            body["start"] = ["date": fmt.string(from: event.start)]
            body["end"] = ["date": fmt.string(from: event.end)]
        } else {
            let fmt = ISO8601DateFormatter()
            body["start"] = ["dateTime": fmt.string(from: event.start)]
            body["end"] = ["dateTime": fmt.string(from: event.end)]
        }

        if let loc = event.location { body["location"] = loc }
        if let desc = event.eventDescription { body["description"] = desc }
        if let rec = event.recurrence {
            body["recurrence"] = rec.components(separatedBy: "\n")
        }
        if let attendeesJSON = event.attendeesJSON,
           let data = attendeesJSON.data(using: .utf8),
           let arr = try? JSONSerialization.jsonObject(with: data) {
            body["attendees"] = arr
        }
        if let reminders = event.remindersJSON,
           let data = reminders.data(using: .utf8),
           let obj = try? JSONSerialization.jsonObject(with: data) {
            body["reminders"] = obj
        }

        return body
    }

    private static func jsonString(_ dict: [String: Any]) -> String {
        (try? String(data: JSONSerialization.data(withJSONObject: dict), encoding: .utf8)) ?? "{}"
    }
}

enum RecurrenceEditScope {
    case thisEvent, thisAndFuture, allEvents
}
