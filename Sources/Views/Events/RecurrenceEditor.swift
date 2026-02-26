import SwiftUI

struct RecurrenceEditorView: View {
    @Binding var rule: String
    @State private var mode: RecurrenceMode = .never
    @State private var freq: String = "WEEKLY"
    @State private var interval: Int = 1
    @State private var selectedDays: Set<String> = []
    @State private var endMode: EndMode = .never
    @State private var endDate: Date = Calendar.current.date(byAdding: .month, value: 3, to: Date())!
    @State private var endCount: Int = 10

    private enum RecurrenceMode: String, CaseIterable {
        case never = "Never"
        case daily = "Every Day"
        case weekly = "Every Week"
        case biweekly = "Every 2 Weeks"
        case monthly = "Every Month"
        case yearly = "Every Year"
        case custom = "Custom…"
    }

    private enum EndMode: String, CaseIterable {
        case never = "Never"
        case onDate = "On Date"
        case afterCount = "After"
    }

    private let dayAbbrevs = ["SU", "MO", "TU", "WE", "TH", "FR", "SA"]
    private let dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    init(rule: Binding<String>) {
        self._rule = rule
        let parsed = Self.parseForUI(rule.wrappedValue)
        _mode = State(initialValue: parsed.mode)
        _freq = State(initialValue: parsed.freq)
        _interval = State(initialValue: parsed.interval)
        _selectedDays = State(initialValue: parsed.days)
        _endMode = State(initialValue: parsed.endMode)
        _endDate = State(initialValue: parsed.endDate)
        _endCount = State(initialValue: parsed.endCount)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Repeat", selection: $mode) {
                ForEach(RecurrenceMode.allCases, id: \.self) { m in
                    Text(m.rawValue).tag(m)
                }
            }
            .onChange(of: mode) { _, newMode in
                applyPreset(newMode)
                buildRule()
            }

            if mode == .custom {
                customEditor
            }
        }
    }

    @ViewBuilder
    private var customEditor: some View {
        HStack {
            Text("Every")
            TextField("", value: $interval, format: .number)
                .frame(width: 40)
                .onChange(of: interval) { _, _ in buildRule() }
            Picker("", selection: $freq) {
                Text("Day(s)").tag("DAILY")
                Text("Week(s)").tag("WEEKLY")
                Text("Month(s)").tag("MONTHLY")
                Text("Year(s)").tag("YEARLY")
            }
            .frame(width: 100)
            .onChange(of: freq) { _, _ in buildRule() }
        }

        if freq == "WEEKLY" {
            HStack(spacing: 4) {
                ForEach(Array(zip(dayAbbrevs, dayNames)), id: \.0) { abbrev, name in
                    Toggle(isOn: Binding(
                        get: { selectedDays.contains(abbrev) },
                        set: { on in
                            if on { selectedDays.insert(abbrev) } else { selectedDays.remove(abbrev) }
                            buildRule()
                        }
                    )) {
                        Text(String(name.prefix(2)))
                            .font(.caption)
                            .frame(width: 28, height: 28)
                    }
                    .toggleStyle(.button)
                    .buttonStyle(.bordered)
                }
            }
        }

        Picker("Ends", selection: $endMode) {
            ForEach(EndMode.allCases, id: \.self) { m in
                Text(m.rawValue).tag(m)
            }
        }
        .onChange(of: endMode) { _, _ in buildRule() }

        if endMode == .onDate {
            DatePicker("End Date", selection: $endDate, displayedComponents: .date)
                .onChange(of: endDate) { _, _ in buildRule() }
        }

        if endMode == .afterCount {
            HStack {
                Text("After")
                TextField("", value: $endCount, format: .number)
                    .frame(width: 40)
                    .onChange(of: endCount) { _, _ in buildRule() }
                Text("occurrences")
            }
        }
    }

    private func applyPreset(_ preset: RecurrenceMode) {
        switch preset {
        case .never: rule = ""; return
        case .daily: freq = "DAILY"; interval = 1
        case .weekly: freq = "WEEKLY"; interval = 1
        case .biweekly: freq = "WEEKLY"; interval = 2
        case .monthly: freq = "MONTHLY"; interval = 1
        case .yearly: freq = "YEARLY"; interval = 1
        case .custom: return
        }
        selectedDays = []
        endMode = .never
    }

    private func buildRule() {
        guard mode != .never else { rule = ""; return }

        var parts = ["FREQ=\(freq)"]
        if interval > 1 { parts.append("INTERVAL=\(interval)") }
        if freq == "WEEKLY", !selectedDays.isEmpty {
            parts.append("BYDAY=\(selectedDays.sorted().joined(separator: ","))")
        }
        switch endMode {
        case .never: break
        case .onDate:
            let fmt = DateFormatter()
            fmt.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
            fmt.timeZone = TimeZone(identifier: "UTC")
            parts.append("UNTIL=\(fmt.string(from: endDate))")
        case .afterCount:
            parts.append("COUNT=\(endCount)")
        }
        rule = "RRULE:" + parts.joined(separator: ";")
    }

    private static func parseForUI(_ rule: String) -> (mode: RecurrenceMode, freq: String, interval: Int,
                                                         days: Set<String>, endMode: EndMode,
                                                         endDate: Date, endCount: Int) {
        guard !rule.isEmpty else {
            return (.never, "WEEKLY", 1, [], .never,
                    Calendar.current.date(byAdding: .month, value: 3, to: Date())!, 10)
        }

        var freq = "WEEKLY"
        var interval = 1
        var days = Set<String>()
        var eMode = EndMode.never
        var eDate = Calendar.current.date(byAdding: .month, value: 3, to: Date())!
        var eCount = 10

        let line = rule.replacingOccurrences(of: "RRULE:", with: "")
        for part in line.split(separator: ";") {
            let kv = part.split(separator: "=", maxSplits: 1)
            guard kv.count == 2 else { continue }
            switch String(kv[0]) {
            case "FREQ": freq = String(kv[1])
            case "INTERVAL": interval = Int(kv[1]) ?? 1
            case "BYDAY": days = Set(String(kv[1]).split(separator: ",").map(String.init))
            case "COUNT": eCount = Int(kv[1]) ?? 10; eMode = .afterCount
            case "UNTIL":
                let fmt = DateFormatter()
                fmt.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
                fmt.timeZone = TimeZone(identifier: "UTC")
                if let d = fmt.date(from: String(kv[1])) { eDate = d; eMode = .onDate }
            default: break
            }
        }

        let mode: RecurrenceMode
        if interval == 1, days.isEmpty, eMode == .never {
            switch freq {
            case "DAILY": mode = .daily
            case "WEEKLY": mode = .weekly
            case "MONTHLY": mode = .monthly
            case "YEARLY": mode = .yearly
            default: mode = .custom
            }
        } else if freq == "WEEKLY", interval == 2, days.isEmpty, eMode == .never {
            mode = .biweekly
        } else {
            mode = .custom
        }

        return (mode, freq, interval, days, eMode, eDate, eCount)
    }
}
