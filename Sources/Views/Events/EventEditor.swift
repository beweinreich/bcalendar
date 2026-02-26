import SwiftUI

struct EventEditorView: View {
    @State var title: String
    @State var location: String
    @State var notes: String
    @State var startDate: Date
    @State var endDate: Date
    @State var isAllDay: Bool
    @State var selectedCalendarId: String
    @State var recurrenceRule: String
    @State var reminderMinutes: Int
    @State var attendees: [Attendee]

    let calendars: [GCalendar]
    let isNewEvent: Bool
    let onSave: (EventEditorData) -> Void
    let onCancel: () -> Void

    init(event: Event? = nil, calendars: [GCalendar], onSave: @escaping (EventEditorData) -> Void, onCancel: @escaping () -> Void) {
        self.calendars = calendars
        self.isNewEvent = event == nil
        self.onSave = onSave
        self.onCancel = onCancel

        let e = event
        _title = State(initialValue: e?.summary ?? "")
        _location = State(initialValue: e?.location ?? "")
        _notes = State(initialValue: e?.eventDescription ?? "")
        _startDate = State(initialValue: e?.start ?? Date())
        _endDate = State(initialValue: e?.end ?? Date().addingTimeInterval(3600))
        _isAllDay = State(initialValue: e?.allDay ?? false)
        _selectedCalendarId = State(initialValue: e?.calendarId ?? calendars.first?.id ?? "")
        _recurrenceRule = State(initialValue: e?.recurrence ?? "")
        _reminderMinutes = State(initialValue: 10)
        _attendees = State(initialValue: AttendeeHelper.parse(json: e?.attendeesJSON))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Title", text: $title)
                .font(.title2)
                .textFieldStyle(.plain)

            Divider()

            Toggle("All-day", isOn: $isAllDay)

            if isAllDay {
                DatePicker("Start", selection: $startDate, displayedComponents: .date)
                DatePicker("End", selection: $endDate, displayedComponents: .date)
            } else {
                DatePicker("Start", selection: $startDate)
                DatePicker("End", selection: $endDate)
            }

            TextField("Location", text: $location)
            TextField("Notes", text: $notes, axis: .vertical)
                .lineLimit(3...6)

            Picker("Calendar", selection: $selectedCalendarId) {
                ForEach(calendars, id: \.id) { cal in
                    HStack {
                        Circle()
                            .fill(Color(GoogleColorMap.color(for: cal.colorHex)))
                            .frame(width: 8, height: 8)
                        Text(cal.summary)
                    }.tag(cal.id)
                }
            }

            RecurrenceEditorView(rule: $recurrenceRule)

            Picker("Reminder", selection: $reminderMinutes) {
                Text("None").tag(0)
                Text("5 minutes before").tag(5)
                Text("10 minutes before").tag(10)
                Text("30 minutes before").tag(30)
                Text("1 hour before").tag(60)
                Text("1 day before").tag(1440)
            }

            AttendeeEditorView(attendees: $attendees,
                               organizerEmail: nil, organizerName: nil,
                               userEmail: nil, onRSVP: nil)

            Divider()

            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button(isNewEvent ? "Create" : "Save") {
                    let data = EventEditorData(
                        title: title, location: location, notes: notes,
                        startDate: startDate, endDate: endDate, isAllDay: isAllDay,
                        calendarId: selectedCalendarId, recurrenceRule: recurrenceRule,
                        reminderMinutes: reminderMinutes, attendees: attendees
                    )
                    onSave(data)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(title.isEmpty)
            }
        }
        .padding(16)
        .frame(width: 380)
    }
}

struct EventEditorData {
    let title: String
    let location: String
    let notes: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let calendarId: String
    let recurrenceRule: String
    let reminderMinutes: Int
    let attendees: [Attendee]
}
