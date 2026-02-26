import AppKit

class CalendarToolbar: NSObject, NSToolbarDelegate {
    let toolbar: NSToolbar
    var onNavigateBack: (() -> Void)?
    var onNavigateForward: (() -> Void)?
    var onToday: (() -> Void)?
    var onViewModeChanged: ((ViewMode) -> Void)?

    private let titleLabel = NSTextField(labelWithString: "")
    private let viewSegment: NSSegmentedControl

    private static let backID = NSToolbarItem.Identifier("back")
    private static let forwardID = NSToolbarItem.Identifier("forward")
    private static let todayID = NSToolbarItem.Identifier("today")
    private static let titleID = NSToolbarItem.Identifier("title")
    private static let viewSwitcherID = NSToolbarItem.Identifier("viewSwitcher")

    override init() {
        toolbar = NSToolbar(identifier: "CalendarToolbar")
        viewSegment = NSSegmentedControl(labels: ["Day", "Week", "Month"],
                                         trackingMode: .selectOne,
                                         target: nil, action: nil)
        super.init()
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        toolbar.allowsUserCustomization = false

        viewSegment.target = self
        viewSegment.action = #selector(viewSegmentChanged(_:))
        viewSegment.selectedSegment = 2

        titleLabel.font = .systemFont(ofSize: 20, weight: .bold)
        titleLabel.alignment = .center
        titleLabel.isEditable = false
        titleLabel.isBordered = false
        titleLabel.backgroundColor = .clear
    }

    func updateTitle(for date: Date, mode: ViewMode) {
        switch mode {
        case .day:
            titleLabel.stringValue = date.formatted(as: "EEEE, MMMM d, yyyy")
        case .week:
            let cal = Calendar.current
            let (start, end) = cal.weekRange(for: date)
            let sameMonth = cal.component(.month, from: start) == cal.component(.month, from: end)
            if sameMonth {
                titleLabel.stringValue = "\(start.formatted(as: "MMM d")) – \(end.formatted(as: "d, yyyy"))"
            } else {
                titleLabel.stringValue = "\(start.formatted(as: "MMM d")) – \(end.formatted(as: "MMM d, yyyy"))"
            }
        case .month:
            titleLabel.stringValue = date.formatted(as: "MMMM yyyy")
        }
    }

    func updateViewMode(_ mode: ViewMode) {
        viewSegment.selectedSegment = mode.rawValue
    }

    @objc private func viewSegmentChanged(_ sender: NSSegmentedControl) {
        if let mode = ViewMode(rawValue: sender.selectedSegment) {
            onViewModeChanged?(mode)
        }
    }

    @objc private func backClicked() { onNavigateBack?() }
    @objc private func forwardClicked() { onNavigateForward?() }
    @objc private func todayClicked() { onToday?() }

    // MARK: - NSToolbarDelegate

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [Self.backID, Self.forwardID, Self.todayID, .flexibleSpace, Self.titleID, .flexibleSpace, Self.viewSwitcherID]
    }

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        toolbarDefaultItemIdentifiers(toolbar)
    }

    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier id: NSToolbarItem.Identifier,
                 willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? {
        let item = NSToolbarItem(itemIdentifier: id)
        switch id {
        case Self.backID:
            item.image = NSImage(systemSymbolName: "chevron.left", accessibilityDescription: "Back")
            item.target = self
            item.action = #selector(backClicked)
            item.label = "Back"
        case Self.forwardID:
            item.image = NSImage(systemSymbolName: "chevron.right", accessibilityDescription: "Forward")
            item.target = self
            item.action = #selector(forwardClicked)
            item.label = "Forward"
        case Self.todayID:
            let btn = NSButton(title: "Today", target: self, action: #selector(todayClicked))
            btn.bezelStyle = .toolbar
            item.view = btn
            item.label = "Today"
        case Self.titleID:
            item.view = titleLabel
            item.label = "Date"
            item.minSize = NSSize(width: 200, height: 24)
            item.maxSize = NSSize(width: 400, height: 24)
        case Self.viewSwitcherID:
            item.view = viewSegment
            item.label = "View"
        default:
            return nil
        }
        return item
    }
}
