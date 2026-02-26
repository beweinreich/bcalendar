import Foundation

extension Calendar {
    func weekRange(for date: Date) -> (start: Date, end: Date) {
        let interval = dateInterval(of: .weekOfYear, for: date)!
        let end = self.date(byAdding: .day, value: 6, to: interval.start)!
        return (interval.start, end)
    }

    func monthGrid(for date: Date) -> (firstOfMonth: Date, daysInMonth: Int, startWeekday: Int) {
        let comps = dateComponents([.year, .month], from: date)
        let firstOfMonth = self.date(from: comps)!
        let daysInMonth = range(of: .day, in: .month, for: firstOfMonth)!.count
        let startWeekday = component(.weekday, from: firstOfMonth)
        return (firstOfMonth, daysInMonth, startWeekday)
    }

    func isToday(_ date: Date) -> Bool {
        isDateInToday(date)
    }

    func isSameDay(_ a: Date, _ b: Date) -> Bool {
        isDate(a, inSameDayAs: b)
    }
}

extension Date {
    func formatted(as format: String) -> String {
        let f = DateFormatter()
        f.dateFormat = format
        return f.string(from: self)
    }
}
