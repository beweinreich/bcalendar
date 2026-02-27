import Foundation

enum ViewMode: Int {
    case day = 0, week = 1, month = 2
}

final class Preferences {
    static let shared = Preferences()
    private let defaults = UserDefaults.standard

    var viewMode: ViewMode {
        get { ViewMode(rawValue: defaults.integer(forKey: "viewMode")) ?? .month }
        set { defaults.set(newValue.rawValue, forKey: "viewMode") }
    }

    var lastDate: Date {
        get { defaults.object(forKey: "lastDate") as? Date ?? Date() }
        set { defaults.set(newValue, forKey: "lastDate") }
    }

    var selectedCalendarIDs: Set<String> {
        get { Set(defaults.stringArray(forKey: "selectedCalendarIDs") ?? []) }
        set { defaults.set(Array(newValue), forKey: "selectedCalendarIDs") }
    }

    var lastUsedCalendarId: String? {
        get { defaults.string(forKey: "lastUsedCalendarId") }
        set { defaults.set(newValue, forKey: "lastUsedCalendarId") }
    }
}
