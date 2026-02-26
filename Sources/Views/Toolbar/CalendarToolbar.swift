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
        titleLabel.alignment = .left
        titleLabel.isEditable = false
        titleLabel.isBordered = false
        titleLabel.backgroundColor = .clear
    }

    func updateTitle(for date: Date, mode: ViewMode) {
        switch mode {
        case .day:
            titleLabel.stringValue = date.formatted(as: "MMM d, yyyy")
        case .week:
            titleLabel.stringValue = date.formatted(as: "MMMM yyyy")
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

    /// Returns a view with the same controls for embedding in the content area (toolbar only over main content).
    func makeEmbeddedView() -> NSView {
        let back = NSButton(image: NSImage(systemSymbolName: "chevron.left", accessibilityDescription: "Back")!,
                            target: self, action: #selector(backClicked))
        back.bezelStyle = .regularSquare
        let forward = NSButton(image: NSImage(systemSymbolName: "chevron.right", accessibilityDescription: "Forward")!,
                               target: self, action: #selector(forwardClicked))
        forward.bezelStyle = .regularSquare
        let today = NSButton(title: "Today", target: self, action: #selector(todayClicked))
        today.bezelStyle = .rounded
        titleLabel.font = .systemFont(ofSize: 20, weight: .bold)
        viewSegment.target = self
        viewSegment.action = #selector(viewSegmentChanged(_:))
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let stack = NSStackView(views: [titleLabel, spacer, viewSegment, today, back, forward])
        stack.orientation = .horizontal
        stack.spacing = 12
        stack.alignment = .centerY
        stack.setCustomSpacing(24, after: viewSegment)
        stack.setHuggingPriority(.defaultLow, for: .horizontal)
        titleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        stack.translatesAutoresizingMaskIntoConstraints = false
        let container = NSView()
        container.wantsLayer = true
        container.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            stack.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            container.heightAnchor.constraint(equalToConstant: 52),
        ])
        return container
    }

    // MARK: - NSToolbarDelegate

    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
        [Self.titleID, .flexibleSpace, Self.viewSwitcherID, Self.todayID, Self.backID, Self.forwardID]
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
