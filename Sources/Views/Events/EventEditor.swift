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
    let accounts: [Account]
    let isNewEvent: Bool
    let onSave: (EventEditorData) -> Void
    let onCancel: () -> Void

    init(event: Event? = nil, startDate: Date? = nil, endDate: Date? = nil, isAllDay: Bool? = nil, calendars: [GCalendar], accounts: [Account], initialCalendarId: String? = nil, onSave: @escaping (EventEditorData) -> Void, onCancel: @escaping () -> Void) {
        self.calendars = calendars
        self.accounts = accounts
        self.isNewEvent = event == nil
        self.onSave = onSave
        self.onCancel = onCancel

        let e = event
        let defaultCalendarId = e?.calendarId
            ?? initialCalendarId.flatMap { id in calendars.contains(where: { $0.id == id }) ? id : nil }
            ?? calendars.first?.id ?? ""
        _title = State(initialValue: e?.summary ?? "")
        _location = State(initialValue: e?.location ?? "")
        _notes = State(initialValue: e?.eventDescription ?? "")
        _startDate = State(initialValue: e?.start ?? startDate ?? Date())
        _endDate = State(initialValue: e?.end ?? endDate ?? Date().addingTimeInterval(3600))
        _isAllDay = State(initialValue: e?.allDay ?? isAllDay ?? false)
        _selectedCalendarId = State(initialValue: defaultCalendarId)
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

            HStack {
                Text("Calendar")
                Spacer()
                CalendarPickerView(accounts: accounts, calendars: calendars, selectedCalendarId: $selectedCalendarId)
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
