import AppKit

// MARK: - Pill Segmented Control

class PillSegmentedControl: NSView {
    private let labels: [String]
    private(set) var selectedIndex: Int = 0
    var onSelectionChanged: ((Int) -> Void)?

    init(labels: [String]) {
        self.labels = labels
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) { fatalError() }

    override var intrinsicContentSize: NSSize {
        NSSize(width: CGFloat(labels.count) * 56 + 8, height: 30)
    }

    func setSelected(_ index: Int) {
        guard index >= 0, index < labels.count else { return }
        selectedIndex = index
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        let bgPath = NSBezierPath(roundedRect: bounds, xRadius: bounds.height / 2, yRadius: bounds.height / 2)
        NSColor.quaternaryLabelColor.setFill()
        bgPath.fill()

        let inset: CGFloat = 3
        let segWidth = (bounds.width - inset * 2) / CGFloat(labels.count)

        for (i, label) in labels.enumerated() {
            let segRect = NSRect(x: inset + CGFloat(i) * segWidth, y: inset,
                                 width: segWidth, height: bounds.height - inset * 2)

            if i == selectedIndex {
                let selPath = NSBezierPath(roundedRect: segRect, xRadius: 7, yRadius: 7)
                NSColor.systemBlue.setFill()
                selPath.fill()
            }

            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 12, weight: .medium),
                .foregroundColor: i == selectedIndex ? NSColor.white : NSColor.secondaryLabelColor
            ]
            let str = NSAttributedString(string: label, attributes: attrs)
            let sz = str.size()
            str.draw(at: NSPoint(x: segRect.midX - sz.width / 2, y: segRect.midY - sz.height / 2))
        }
    }

    override func mouseDown(with event: NSEvent) {
        let pt = convert(event.locationInWindow, from: nil)
        let inset: CGFloat = 3
        let segWidth = (bounds.width - inset * 2) / CGFloat(labels.count)
        let index = Int((pt.x - inset) / segWidth)
        if index >= 0, index < labels.count, index != selectedIndex {
            selectedIndex = index
            needsDisplay = true
            onSelectionChanged?(index)
        }
    }
}

// MARK: - Toolbar

class CalendarToolbar: NSObject, NSToolbarDelegate {
    let toolbar: NSToolbar
    var onNavigateBack: (() -> Void)?
    var onNavigateForward: (() -> Void)?
    var onToday: (() -> Void)?
    var onViewModeChanged: ((ViewMode) -> Void)?

    private let titleLabel = NSTextField(labelWithString: "")
    private let pillSegment: PillSegmentedControl
    private let activityIndicator = NSProgressIndicator()

    private static let backID = NSToolbarItem.Identifier("back")
    private static let forwardID = NSToolbarItem.Identifier("forward")
    private static let todayID = NSToolbarItem.Identifier("today")
    private static let titleID = NSToolbarItem.Identifier("title")
    private static let viewSwitcherID = NSToolbarItem.Identifier("viewSwitcher")

    override init() {
        toolbar = NSToolbar(identifier: "CalendarToolbar")
        pillSegment = PillSegmentedControl(labels: ["Day", "Week", "Month"])
        super.init()
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        toolbar.allowsUserCustomization = false

        pillSegment.setSelected(2)
        pillSegment.onSelectionChanged = { [weak self] index in
            if let mode = ViewMode(rawValue: index) {
                self?.onViewModeChanged?(mode)
            }
        }

        titleLabel.font = .systemFont(ofSize: 22, weight: .medium)
        titleLabel.alignment = .left
        titleLabel.isEditable = false
        titleLabel.isBordered = false
        titleLabel.backgroundColor = .clear

        activityIndicator.style = .spinning
        activityIndicator.controlSize = .small
        activityIndicator.isDisplayedWhenStopped = false

        NotificationCenter.default.addObserver(
            self, selector: #selector(apiActivityChanged),
            name: .apiActivityChanged, object: nil
        )
    }

    @objc private func apiActivityChanged(_ notification: Notification) {
        let active = (notification.userInfo?["active"] as? Bool) ?? false
        if active {
            activityIndicator.startAnimation(nil)
        } else {
            activityIndicator.stopAnimation(nil)
        }
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
        pillSegment.setSelected(mode.rawValue)
    }

    @objc private func backClicked() { onNavigateBack?() }
    @objc private func forwardClicked() { onNavigateForward?() }
    @objc private func todayClicked() { onToday?() }

    func makeEmbeddedView() -> NSView {
        let back = NSButton(image: NSImage(systemSymbolName: "chevron.left", accessibilityDescription: "Back")!,
                            target: self, action: #selector(backClicked))
        back.bezelStyle = .regularSquare
        back.isBordered = false
        let forward = NSButton(image: NSImage(systemSymbolName: "chevron.right", accessibilityDescription: "Forward")!,
                               target: self, action: #selector(forwardClicked))
        forward.bezelStyle = .regularSquare
        forward.isBordered = false
        let today = NSButton(title: "Today", target: self, action: #selector(todayClicked))
        today.bezelStyle = .rounded
        titleLabel.font = .systemFont(ofSize: 22, weight: .medium)

        pillSegment.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            pillSegment.widthAnchor.constraint(equalToConstant: pillSegment.intrinsicContentSize.width),
            pillSegment.heightAnchor.constraint(equalToConstant: 30),
        ])

        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            activityIndicator.widthAnchor.constraint(equalToConstant: 16),
            activityIndicator.heightAnchor.constraint(equalToConstant: 16),
        ])

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let stack = NSStackView(views: [titleLabel, spacer, activityIndicator, pillSegment, today, back, forward])
        stack.orientation = .horizontal
        stack.spacing = 12
        stack.alignment = .centerY
        stack.setCustomSpacing(8, after: activityIndicator)
        stack.setCustomSpacing(24, after: pillSegment)
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
            container.heightAnchor.constraint(equalToConstant: 56),
        ])
        if APIActivityTracker.shared.isActive {
            activityIndicator.startAnimation(nil)
        }
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
            item.view = pillSegment
            item.label = "View"
        default:
            return nil
        }
        return item
    }
}
