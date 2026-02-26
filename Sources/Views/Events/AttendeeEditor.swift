import SwiftUI

struct Attendee: Identifiable, Codable {
    var id: String { email }
    var email: String
    var displayName: String?
    var responseStatus: String
    var isSelf: Bool?

    var statusIcon: String {
        switch responseStatus {
        case "accepted": return "checkmark.circle.fill"
        case "declined": return "xmark.circle.fill"
        case "tentative": return "questionmark.circle.fill"
        default: return "circle"
        }
    }

    var statusColor: Color {
        switch responseStatus {
        case "accepted": return .green
        case "declined": return .red
        case "tentative": return .orange
        default: return .secondary
        }
    }
}

struct AttendeeEditorView: View {
    @Binding var attendees: [Attendee]
    @State private var newEmail = ""

    let organizerEmail: String?
    let organizerName: String?
    let userEmail: String?
    let onRSVP: ((String) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let name = organizerName ?? organizerEmail {
                HStack {
                    Image(systemName: "person.fill")
                        .foregroundColor(.secondary)
                    Text("Organizer: \(name)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if !attendees.isEmpty {
                ForEach(attendees) { attendee in
                    HStack {
                        Image(systemName: attendee.statusIcon)
                            .foregroundColor(attendee.statusColor)
                            .frame(width: 16)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(attendee.displayName ?? attendee.email)
                                .font(.callout)
                            if attendee.displayName != nil {
                                Text(attendee.email)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                        if attendee.isSelf == true {
                            Text("You")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 4)
                                .background(.quaternary)
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.vertical, 2)
                }
            }

            if let userEmail = userEmail,
               attendees.contains(where: { $0.email == userEmail }) {
                Divider()
                HStack(spacing: 8) {
                    Text("RSVP:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Button("Accept") { onRSVP?("accepted") }
                        .buttonStyle(.bordered)
                    Button("Maybe") { onRSVP?("tentative") }
                        .buttonStyle(.bordered)
                    Button("Decline") { onRSVP?("declined") }
                        .buttonStyle(.bordered)
                }
            }

            Divider()

            HStack {
                TextField("Add attendee email", text: $newEmail)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { addAttendee() }
                Button("Add") { addAttendee() }
                    .disabled(newEmail.isEmpty)
            }
        }
    }

    private func addAttendee() {
        let email = newEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !email.isEmpty, email.contains("@") else { return }
        guard !attendees.contains(where: { $0.email == email }) else { return }
        attendees.append(Attendee(email: email, responseStatus: "needsAction"))
        newEmail = ""
    }
}

enum AttendeeHelper {
    static func parse(json: String?) -> [Attendee] {
        guard let json = json, let data = json.data(using: .utf8),
              let arr = try? JSONDecoder().decode([Attendee].self, from: data) else { return [] }
        return arr
    }

    static func toJSON(_ attendees: [Attendee]) -> String? {
        guard let data = try? JSONEncoder().encode(attendees) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func rsvp(event: Event, status: String, userEmail: String) {
        var attendees = parse(json: event.attendeesJSON)
        guard let idx = attendees.firstIndex(where: { $0.email == userEmail }) else { return }
        attendees[idx].responseStatus = status

        let store = EventStore(db: DatabaseManager.shared.pool)
        var updated = event
        updated.attendeesJSON = toJSON(attendees)
        updated.dirtyState = Event.DirtyState.modified.rawValue
        try? store.save(updated)

        let body: [String: Any] = [
            "attendees": attendees.map { att -> [String: Any] in
                var d: [String: Any] = ["email": att.email, "responseStatus": att.responseStatus]
                if let name = att.displayName { d["displayName"] = name }
                return d
            }
        ]
        let payload = (try? String(data: JSONSerialization.data(withJSONObject: body), encoding: .utf8)) ?? "{}"
        let op = PendingOp(accountId: event.accountId, calendarId: event.calendarId,
                           eventId: event.id, opType: .rsvp, payloadJSON: payload)
        OfflineQueue.shared.enqueue(op)

        NotificationCenter.default.post(name: .eventsChanged, object: nil)
    }
}
