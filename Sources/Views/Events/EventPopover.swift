import AppKit
import SwiftUI

class EventPopoverController: NSViewController {
    private var event: Event?
    private var calendarColor: NSColor = .systemBlue

    var onEdit: ((Event) -> Void)?
    var onDelete: ((Event) -> Void)?

    func configure(event: Event, color: NSColor) {
        self.event = event
        self.calendarColor = color
    }

    override func loadView() {
        guard let event = event else {
            view = NSView(frame: NSRect(x: 0, y: 0, width: 280, height: 100))
            return
        }

        let content = EventPopoverView(
            event: event,
            color: Color(calendarColor),
            onEdit: { [weak self] in
                self?.dismiss(nil)
                self?.onEdit?(event)
            },
            onDelete: { [weak self] in
                self?.dismiss(nil)
                self?.onDelete?(event)
            },
            onRSVP: { [weak self] status in
                guard let event = self?.event else { return }
                let accounts = (try? AccountStore(db: DatabaseManager.shared.pool).all()) ?? []
                let userEmail = accounts.first(where: { $0.id == event.accountId })?.email ?? ""
                AttendeeHelper.rsvp(event: event, status: status, userEmail: userEmail)
                self?.dismiss(nil)
            }
        )

        let hostingView = NSHostingView(rootView: content)
        hostingView.frame = NSRect(x: 0, y: 0, width: 300, height: 400)
        view = hostingView
    }
}

struct EventPopoverView: View {
    let event: Event
    let color: Color
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onRSVP: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.25))
                .frame(height: 5)

            Text(event.summary)
                .font(.title3.bold())

            timeRow

            if let location = event.location, !location.isEmpty {
                Label(location, systemImage: "mappin")
                    .font(.callout)
                    .foregroundColor(.secondary)
            }

            if let desc = event.eventDescription, !desc.isEmpty {
                Text(desc)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(4)
            }

            if event.organizerEmail != nil || !attendees.isEmpty {
                Divider()
                attendeeSection
            }

            Divider()

            HStack {
                Spacer()
                Button("Edit", action: onEdit)
                Button("Delete", role: .destructive, action: onDelete)
            }
        }
        .padding(14)
        .frame(width: 300)
    }

    private var timeRow: some View {
        let fmt = DateFormatter()
        if event.allDay {
            fmt.dateStyle = .medium
            fmt.timeStyle = .none
        } else {
            fmt.dateStyle = .medium
            fmt.timeStyle = .short
        }
        return Label(
            "\(fmt.string(from: event.start)) – \(fmt.string(from: event.end))",
            systemImage: "clock"
        )
        .font(.callout)
        .foregroundColor(.secondary)
    }

    private var attendees: [Attendee] {
        AttendeeHelper.parse(json: event.attendeesJSON)
    }

    private var userEmail: String? {
        let accounts = (try? AccountStore(db: DatabaseManager.shared.pool).all()) ?? []
        return accounts.first(where: { $0.id == event.accountId })?.email
    }

    @ViewBuilder
    private var attendeeSection: some View {
        if let name = event.organizerName ?? event.organizerEmail {
            HStack {
                Image(systemName: "person.fill")
                    .foregroundColor(.secondary)
                Text("Organizer: \(name)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }

        ForEach(attendees) { att in
            HStack(spacing: 6) {
                Image(systemName: att.statusIcon)
                    .foregroundColor(att.statusColor)
                    .frame(width: 14)
                Text(att.displayName ?? att.email)
                    .font(.caption)
                if att.isSelf == true {
                    Text("You")
                        .font(.caption2)
                        .padding(.horizontal, 4)
                        .background(.quaternary)
                        .clipShape(Capsule())
                }
            }
        }

        if let email = userEmail, attendees.contains(where: { $0.email == email }) {
            HStack(spacing: 6) {
                Text("RSVP:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Button("Accept") { onRSVP("accepted") }.buttonStyle(.bordered).controlSize(.small)
                Button("Maybe") { onRSVP("tentative") }.buttonStyle(.bordered).controlSize(.small)
                Button("Decline") { onRSVP("declined") }.buttonStyle(.bordered).controlSize(.small)
            }
        }
    }
}
