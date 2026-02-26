import Foundation
import AppKit
import GRDB

final class EventDataSource {
    private let eventStore = EventStore(db: DatabaseManager.shared.pool)
    private let calendarStore = CalendarStore(db: DatabaseManager.shared.pool)

    private var colorMap: [String: NSColor] = [:]
    private var prefetchCache: [String: [Event]] = [:]

    func calendarColors(for calId: String) -> NSColor {
        colorMap[calId] ?? .systemBlue
    }

    func reload() {
        if let calendars = try? calendarStore.selected() {
            colorMap = [:]
            for cal in calendars {
                colorMap[cal.id] = GoogleColorMap.color(for: cal.colorHex)
            }
        }
        prefetchCache.removeAll()
    }

    func selectedCalendarIDs() -> [String] {
        (try? calendarStore.selected().map(\.id)) ?? []
    }

    private func fetchAndExpand(from start: Date, to end: Date) -> [Event] {
        let key = "\(Int(start.timeIntervalSince1970))-\(Int(end.timeIntervalSince1970))"
        if let cached = prefetchCache[key] { return cached }

        let calIds = selectedCalendarIDs()
        guard !calIds.isEmpty else { return [] }
        let raw = (try? eventStore.events(in: calIds, from: start, to: end)) ?? []
        let expanded = RecurrenceExpander.expand(events: raw, from: start, to: end)
        prefetchCache[key] = expanded
        return expanded
    }

    private func toDisplay(_ event: Event) -> DisplayEvent {
        DisplayEvent(id: event.id, title: event.summary,
                     start: event.start, end: event.end,
                     isAllDay: event.allDay,
                     color: colorMap[event.calendarId] ?? .systemBlue,
                     calendarID: event.calendarId)
    }

    func eventsForMonth(date: Date) -> [[DisplayEvent]] {
        let cal = Calendar.current
        let (firstOfMonth, daysInMonth, _) = cal.monthGrid(for: date)
        let endOfMonth = cal.date(byAdding: .day, value: daysInMonth, to: firstOfMonth)!
        let events = fetchAndExpand(from: firstOfMonth, to: endOfMonth)

        var result = Array(repeating: [DisplayEvent](), count: daysInMonth)
        for event in events {
            let dayIndex = cal.dateComponents([.day], from: firstOfMonth, to: event.start).day ?? 0
            if dayIndex >= 0, dayIndex < daysInMonth {
                result[dayIndex].append(toDisplay(event))
            }
        }

        prefetchAdjacentMonth(date: date)
        return result
    }

    func eventsForWeek(date: Date) -> [Int: [DisplayEvent]] {
        let cal = Calendar.current
        let weekStart = cal.dateInterval(of: .weekOfYear, for: date)!.start
        let weekEnd = cal.date(byAdding: .day, value: 7, to: weekStart)!
        let events = fetchAndExpand(from: weekStart, to: weekEnd)

        var result: [Int: [DisplayEvent]] = [:]
        for event in events {
            let col = cal.dateComponents([.day], from: weekStart, to: event.start).day ?? 0
            if col >= 0, col < 7 {
                result[col, default: []].append(toDisplay(event))
            }
        }

        prefetchAdjacentWeek(date: date)
        return result
    }

    func eventsForRange(startDate: Date, days: Int) -> [Int: [DisplayEvent]] {
        let cal = Calendar.current
        let start = cal.startOfDay(for: startDate)
        let end = cal.date(byAdding: .day, value: days, to: start)!
        let events = fetchAndExpand(from: start, to: end)

        var result: [Int: [DisplayEvent]] = [:]
        for event in events {
            let col = cal.dateComponents([.day], from: start, to: event.start).day ?? 0
            if col >= 0, col < days {
                result[col, default: []].append(toDisplay(event))
            }
        }
        return result
    }

    func eventsForDay(date: Date) -> [Int: [DisplayEvent]] {
        let cal = Calendar.current
        let dayStart = cal.startOfDay(for: date)
        let dayEnd = cal.date(byAdding: .day, value: 1, to: dayStart)!
        let events = fetchAndExpand(from: dayStart, to: dayEnd)

        var result: [Int: [DisplayEvent]] = [:]
        for event in events {
            result[0, default: []].append(toDisplay(event))
        }
        return result
    }

    // MARK: - Prefetch

    private func prefetchAdjacentMonth(date: Date) {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let cal = Calendar.current
            let prev = cal.date(byAdding: .month, value: -1, to: date)!
            let next = cal.date(byAdding: .month, value: 1, to: date)!
            _ = self?.fetchAndExpand(from: cal.monthGrid(for: prev).firstOfMonth,
                                     to: cal.date(byAdding: .month, value: 1, to: cal.monthGrid(for: prev).firstOfMonth)!)
            _ = self?.fetchAndExpand(from: cal.monthGrid(for: next).firstOfMonth,
                                     to: cal.date(byAdding: .month, value: 1, to: cal.monthGrid(for: next).firstOfMonth)!)
        }
    }

    private func prefetchAdjacentWeek(date: Date) {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let cal = Calendar.current
            let prev = cal.date(byAdding: .weekOfYear, value: -1, to: date)!
            let next = cal.date(byAdding: .weekOfYear, value: 1, to: date)!
            for d in [prev, next] {
                let start = cal.dateInterval(of: .weekOfYear, for: d)!.start
                let end = cal.date(byAdding: .day, value: 7, to: start)!
                _ = self?.fetchAndExpand(from: start, to: end)
            }
        }
    }
}
