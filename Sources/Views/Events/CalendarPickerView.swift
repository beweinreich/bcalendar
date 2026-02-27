import SwiftUI

/// Calendar selection menu with accounts as section headers and calendars nested underneath, each with a colored dot.
struct CalendarPickerView: View {
    let accounts: [Account]
    let calendars: [GCalendar]
    @Binding var selectedCalendarId: String

    private var calendarsByAccount: [(account: Account, calendars: [GCalendar])] {
        let byAccount = Dictionary(grouping: calendars, by: \.accountId)
        return accounts.compactMap { acct in
            guard let cals = byAccount[acct.id], !cals.isEmpty else { return nil }
            return (acct, cals)
        }
    }

    private var selectedCalendar: GCalendar? {
        calendars.first { $0.id == selectedCalendarId }
    }

    var body: some View {
        Menu {
            ForEach(calendarsByAccount, id: \.account.id) { pair in
                Section(pair.account.email) {
                    ForEach(pair.calendars, id: \.id) { cal in
                        Button {
                            selectedCalendarId = cal.id
                        } label: {
                            HStack(spacing: 8) {
                                if selectedCalendarId == cal.id {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 10, weight: .bold))
                                }
                                Circle()
                                    .fill(Color(GoogleColorMap.color(for: cal.colorHex)))
                                    .frame(width: 10, height: 10)
                                Text(cal.summary)
                            }
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 8) {
                if let cal = selectedCalendar {
                    Circle()
                        .fill(Color(GoogleColorMap.color(for: cal.colorHex)))
                        .frame(width: 10, height: 10)
                }
                Text(selectedCalendar?.summary ?? "Calendar")
                    .foregroundStyle(.primary)
            }
        }
    }
}
