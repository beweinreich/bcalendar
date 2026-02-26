import Foundation

enum RecurrenceExpander {
    static func expand(events: [Event], from rangeStart: Date, to rangeEnd: Date) -> [Event] {
        var result: [Event] = []
        var exceptions: [String: Set<Date>] = [:]

        for event in events where event.recurringEventId != nil {
            if let origStart = event.originalStartTime {
                exceptions[event.recurringEventId!, default: []].insert(Calendar.current.startOfDay(for: origStart))
            }
        }

        for event in events {
            if event.recurringEventId != nil {
                result.append(event)
                continue
            }

            guard let rruleStr = event.recurrence, !rruleStr.isEmpty else {
                result.append(event)
                continue
            }

            let rule = parseRRule(rruleStr)
            let exDates = exceptions[event.id] ?? []
            let instances = generateInstances(event: event, rule: rule, exDates: exDates,
                                               rangeStart: rangeStart, rangeEnd: rangeEnd)
            result.append(contentsOf: instances)
        }

        return result
    }

    private struct RRule {
        var freq: String = "WEEKLY"
        var interval: Int = 1
        var count: Int?
        var until: Date?
        var byDay: [String] = []
    }

    private static func parseRRule(_ str: String) -> RRule {
        var rule = RRule()
        let lines = str.components(separatedBy: "\n")
        for line in lines {
            guard line.hasPrefix("RRULE:") else { continue }
            let parts = line.dropFirst(6).components(separatedBy: ";")
            for part in parts {
                let kv = part.split(separator: "=", maxSplits: 1)
                guard kv.count == 2 else { continue }
                let key = String(kv[0])
                let val = String(kv[1])
                switch key {
                case "FREQ": rule.freq = val
                case "INTERVAL": rule.interval = Int(val) ?? 1
                case "COUNT": rule.count = Int(val)
                case "UNTIL":
                    let fmt = DateFormatter()
                    fmt.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
                    fmt.timeZone = TimeZone(identifier: "UTC")
                    rule.until = fmt.date(from: val)
                case "BYDAY": rule.byDay = val.components(separatedBy: ",")
                default: break
                }
            }
        }
        return rule
    }

    private static func generateInstances(event: Event, rule: RRule, exDates: Set<Date>,
                                            rangeStart: Date, rangeEnd: Date) -> [Event] {
        let cal = Calendar.current
        let duration = event.end.timeIntervalSince(event.start)
        var instances: [Event] = []
        var current = event.start
        var count = 0
        let maxCount = rule.count ?? 500

        let component: Calendar.Component
        switch rule.freq {
        case "DAILY": component = .day
        case "WEEKLY": component = .weekOfYear
        case "MONTHLY": component = .month
        case "YEARLY": component = .year
        default: component = .weekOfYear
        }

        while current < rangeEnd, count < maxCount {
            if let until = rule.until, current > until { break }

            if current >= rangeStart {
                let dayStart = cal.startOfDay(for: current)
                if !exDates.contains(dayStart) {
                    var instance = event
                    instance.id = "\(event.id)_\(Int(current.timeIntervalSince1970))"
                    instance.start = current
                    instance.end = current.addingTimeInterval(duration)
                    instance.recurringEventId = event.id
                    instance.recurrence = nil
                    instances.append(instance)
                }
            }

            count += 1
            current = cal.date(byAdding: component, value: rule.interval, to: current)!
        }

        return instances
    }
}
