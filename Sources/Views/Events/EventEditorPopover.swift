import AppKit
import SwiftUI

private class PopoverCloseDelegate: NSObject, NSPopoverDelegate {
    var onClose: (() -> Void)?

    func popoverDidClose(_ notification: Notification) {
        onClose?()
    }
}

/// Apple Calendar-style popover for creating/editing events.
enum EventEditorPopover {
    static func showCreate(startDate: Date, endDate: Date, allDay: Bool, calendarId: String?,
                          anchorRect: NSRect, in view: NSView, onDismiss: @escaping () -> Void) {
        let db = DatabaseManager.shared.pool
        let calendars = (try? CalendarStore(db: db).selected()) ?? []
        guard !calendars.isEmpty else { return }
        let accounts = (try? AccountStore(db: db).all()) ?? []
        let defaultAccountId = accounts.first?.id ?? "demo"

        let defaultCalendarId = calendarId
            ?? Preferences.shared.lastUsedCalendarId.flatMap { id in calendars.contains(where: { $0.id == id }) ? id : nil }
            ?? calendars.first!.id

        let popover = NSPopover()
        popover.behavior = .transient

        let delegate = PopoverCloseDelegate()
        delegate.onClose = onDismiss
        popover.delegate = delegate
        objc_setAssociatedObject(popover, &PopoverCloseDelegate.associatedKey, delegate, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

        let editorView = EventEditorView(
            event: nil,
            startDate: startDate,
            endDate: endDate,
            isAllDay: allDay,
            calendars: calendars,
            accounts: accounts,
            initialCalendarId: defaultCalendarId,
            onSave: { data in
                let accountId = calendars.first(where: { $0.id == data.calendarId })
                    .flatMap({ acct in accounts.first(where: { $0.id == acct.accountId }) })?.id ?? defaultAccountId
                if EventActions.createEvent(data: data, accountId: accountId) {
                    Preferences.shared.lastUsedCalendarId = data.calendarId
                    popover.close()
                } else {
                    let alert = NSAlert()
                    alert.messageText = "Could Not Create Event"
                    alert.informativeText = "Failed to save the event. Please try again."
                    alert.addButton(withTitle: "OK")
                    alert.beginSheetModal(for: view.window!)
                }
            },
            onCancel: {
                popover.close()
            }
        )

        popover.contentViewController = NSHostingController(rootView: editorView)
        popover.contentSize = NSSize(width: 400, height: 500)
        popover.show(relativeTo: anchorRect, of: view, preferredEdge: .maxX)
    }

    static func showEdit(event: Event, anchorRect: NSRect, in view: NSView, onDismiss: @escaping () -> Void) {
        let db = DatabaseManager.shared.pool
        let calendars = (try? CalendarStore(db: db).selected()) ?? []
        let accounts = (try? AccountStore(db: db).all()) ?? []

        let popover = NSPopover()
        popover.behavior = .transient

        let delegate = PopoverCloseDelegate()
        delegate.onClose = onDismiss
        popover.delegate = delegate
        objc_setAssociatedObject(popover, &PopoverCloseDelegate.associatedKey, delegate, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

        let editorView = EventEditorView(
            event: event,
            calendars: calendars,
            accounts: accounts,
            onSave: { data in
                EventActions.updateEvent(event, data: data)
                popover.close()
            },
            onCancel: {
                popover.close()
            }
        )

        popover.contentViewController = NSHostingController(rootView: editorView)
        popover.contentSize = NSSize(width: 400, height: 500)
        popover.show(relativeTo: anchorRect, of: view, preferredEdge: .maxX)
    }
}

private extension PopoverCloseDelegate {
    static var associatedKey: UInt8 = 0
}
