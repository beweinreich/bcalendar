import AppKit
import SwiftUI

enum EventEditorWindow {
    static func showCreate(startDate: Date, endDate: Date, allDay: Bool, calendarId: String?,
                           relativeTo window: NSWindow?) {
        let db = DatabaseManager.shared.pool
        let calendars = (try? CalendarStore(db: db).selected()) ?? []
        guard !calendars.isEmpty else { return }
        let accounts = (try? AccountStore(db: db).all()) ?? []
        let defaultAccountId = accounts.first?.id ?? "demo"

        var seedEvent = Event(accountId: defaultAccountId, calendarId: calendarId ?? calendars.first!.id,
                              summary: "", start: startDate, end: endDate, allDay: allDay)

        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 400, height: 500),
                            styleMask: [.titled, .closable], backing: .buffered, defer: false)
        panel.title = "New Event"

        let editorView = EventEditorView(event: nil, startDate: startDate, endDate: endDate, isAllDay: allDay, calendars: calendars, onSave: { data in
            let accountId = calendars.first(where: { $0.id == data.calendarId })
                .flatMap({ acct in accounts.first(where: { $0.id == acct.accountId }) })?.id ?? defaultAccountId
            EventActions.createEvent(data: data, accountId: accountId)
            panel.close()
        }, onCancel: {
            panel.close()
        })

        panel.contentView = NSHostingView(rootView: editorView)
        panel.center()
        window?.beginSheet(panel)
    }

    static func showEdit(event: Event, relativeTo window: NSWindow?) {
        let db = DatabaseManager.shared.pool
        let calendars = (try? CalendarStore(db: db).selected()) ?? []

        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 400, height: 500),
                            styleMask: [.titled, .closable], backing: .buffered, defer: false)
        panel.title = "Edit Event"

        let editorView = EventEditorView(event: event, calendars: calendars, onSave: { data in
            EventActions.updateEvent(event, data: data)
            panel.close()
        }, onCancel: {
            panel.close()
        })

        panel.contentView = NSHostingView(rootView: editorView)
        panel.center()
        window?.beginSheet(panel)
    }

    static func confirmRecurringAction(title: String, window: NSWindow?,
                                        completion: @escaping (RecurrenceEditScope) -> Void) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = "This is a recurring event."
        alert.addButton(withTitle: "This Event Only")
        alert.addButton(withTitle: "This and Future Events")
        alert.addButton(withTitle: "All Events")
        alert.addButton(withTitle: "Cancel")

        if let window = window {
            alert.beginSheetModal(for: window) { response in
                switch response {
                case .alertFirstButtonReturn: completion(.thisEvent)
                case .alertSecondButtonReturn: completion(.thisAndFuture)
                case .alertThirdButtonReturn: completion(.allEvents)
                default: break
                }
            }
        }
    }
}
