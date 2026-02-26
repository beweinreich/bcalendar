import Foundation

enum DemoData {
    static func seedIfNeeded() {
        let db = DatabaseManager.shared.pool
        let accountStore = AccountStore(db: db)
        let calendarStore = CalendarStore(db: db)
        let eventStore = EventStore(db: db)

        guard (try? accountStore.all())?.isEmpty == true else { return }

        let account = Account(id: "demo", email: "demo@example.com", displayName: "Demo Account")
        try? accountStore.save(account)

        let workCal = GCalendar(id: "work", accountId: "demo", summary: "Work", colorHex: "#4285F4")
        let personalCal = GCalendar(id: "personal", accountId: "demo", summary: "Personal", colorHex: "#34A853")
        try? calendarStore.save(workCal)
        try? calendarStore.save(personalCal)

        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())

        let events: [(String, String, Int, Int, Int, Bool)] = [
            ("Team Standup", "work", 0, 9, 10, false),
            ("Lunch Break", "personal", 0, 12, 13, false),
            ("Project Review", "work", 0, 14, 15, false),
            ("Gym", "personal", 0, 17, 18, false),
            ("Sprint Planning", "work", 1, 10, 12, false),
            ("Dentist", "personal", 2, 11, 12, false),
            ("1:1 with Manager", "work", 2, 14, 14, false),
            ("Team Dinner", "personal", 3, 18, 20, false),
            ("All Hands", "work", -1, 0, 0, true),
            ("Design Review", "work", 4, 13, 14, false),
            ("Coffee Chat", "personal", -2, 10, 11, false),
            ("Board Meeting", "work", 5, 9, 11, false),
        ]

        for (title, calId, dayOffset, startHour, endHour, allDay) in events {
            let day = cal.date(byAdding: .day, value: dayOffset, to: today)!
            let start: Date
            let end: Date
            if allDay {
                start = day
                end = cal.date(byAdding: .day, value: 1, to: day)!
            } else {
                start = cal.date(bySettingHour: startHour, minute: 0, second: 0, of: day)!
                let endH = endHour > startHour ? endHour : startHour + 1
                end = cal.date(bySettingHour: endH, minute: 0, second: 0, of: day)!
            }
            let event = Event(accountId: "demo", calendarId: calId, summary: title,
                              start: start, end: end, allDay: allDay)
            try? eventStore.save(event)
        }
    }
}
