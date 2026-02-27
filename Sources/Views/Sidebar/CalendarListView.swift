import AppKit

private class HoverableCalendarCell: NSView {
    var isHovered = false {
        didSet { needsDisplay = true }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }
    required init?(coder: NSCoder) { super.init(coder: coder); wantsLayer = true }

    override var wantsUpdateLayer: Bool { true }
    override func updateLayer() {
        layer?.cornerRadius = 8
        layer?.backgroundColor = isHovered ? hoverColor.cgColor : NSColor.clear.cgColor
    }

    private var hoverColor: NSColor {
        let base = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            ? NSColor.white : NSColor.black
        return base.withAlphaComponent(0.2)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach { removeTrackingArea($0) }
        addTrackingArea(NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeInKeyWindow], owner: self, userInfo: nil))
    }

    override func mouseEntered(with event: NSEvent) { isHovered = true }
    override func mouseExited(with event: NSEvent) { isHovered = false }
}

private class NoDisclosureOutlineView: NSOutlineView {
    override func frameOfOutlineCell(atRow row: Int) -> NSRect { .zero }
    override func frameOfCell(atColumn column: Int, row: Int) -> NSRect {
        var rect = super.frameOfCell(atColumn: column, row: row)
        let inset: CGFloat = 8
        rect.origin.x = inset
        rect.size.width = bounds.width - inset * 2
        return rect
    }
}

class CalendarListView: NSView {
    private let outlineView = NoDisclosureOutlineView()
    private let scrollView = NSScrollView()
    private var accounts: [Account] = []
    private var calendarsByAccount: [String: [GCalendar]] = [:]

    override init(frame: NSRect) {
        super.init(frame: frame)
        setup()
        reload()
        NotificationCenter.default.addObserver(self, selector: #selector(reload),
                                                name: .calendarsChanged, object: nil)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private static let contentColId = NSUserInterfaceItemIdentifier("content")

    private func setup() {
        let contentCol = NSTableColumn(identifier: Self.contentColId)
        contentCol.title = ""
        outlineView.addTableColumn(contentCol)
        outlineView.outlineTableColumn = contentCol
        outlineView.headerView = nil
        outlineView.dataSource = self
        outlineView.delegate = self
        outlineView.indentationPerLevel = 0
        outlineView.intercellSpacing = NSSize(width: 0, height: 2)
        outlineView.backgroundColor = .clear

        scrollView.documentView = outlineView
        scrollView.contentView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    @objc func reload() {
        let db = DatabaseManager.shared.pool
        accounts = (try? AccountStore(db: db).all()) ?? []
        calendarsByAccount = [:]
        for acct in accounts {
            calendarsByAccount[acct.id] = (try? CalendarStore(db: db).forAccount(acct.id)) ?? []
        }
        outlineView.reloadData()
        for acct in accounts {
            outlineView.expandItem(acct.id)
        }

    }

    @objc private func addAccountClicked() {
        guard GoogleAuthManager.shared.isConfigured else {
            let alert = NSAlert()
            alert.messageText = "OAuth Not Configured"
            alert.informativeText = AuthError.notConfigured.errorDescription!
            alert.runModal()
            return
        }

        Task {
            do {
                let (account, _) = try await GoogleAuthManager.shared.authenticate()
                try AccountStore(db: DatabaseManager.shared.pool).save(account)

                let api = GoogleAPIClient()
                let items = try await api.fetchCalendarList(accountId: account.id)
                let calStore = CalendarStore(db: DatabaseManager.shared.pool)
                for item in items {
                    let cal = GCalendar(
                        id: item["id"] as? String ?? UUID().uuidString,
                        accountId: account.id,
                        summary: item["summary"] as? String ?? "Untitled",
                        colorHex: item["backgroundColor"] as? String ?? "#4285F4",
                        accessRole: item["accessRole"] as? String ?? "reader",
                        isPrimary: item["primary"] as? Bool ?? false,
                        timeZone: item["timeZone"] as? String
                    )
                    try calStore.save(cal)
                }
                NotificationCenter.default.post(name: .calendarsChanged, object: nil)
            } catch {
                let alert = NSAlert(error: error)
                alert.runModal()
            }
        }
    }

    @objc private func calendarCheckboxToggled(_ sender: NSButton) {
        let row = outlineView.row(for: sender)
        guard row >= 0, let calId = outlineView.item(atRow: row) as? String,
              !accounts.contains(where: { $0.id == calId }) else { return }
        try? CalendarStore(db: DatabaseManager.shared.pool).toggleSelected(calId)
        NotificationCenter.default.post(name: .calendarsChanged, object: nil)
        NotificationCenter.default.post(name: .eventsChanged, object: nil)
    }

    @objc private func accountRowToggled(_ sender: NSButton) {
        let row = outlineView.row(for: sender)
        guard row >= 0, let item = outlineView.item(atRow: row),
              accounts.contains(where: { $0.id == item as? String }) else { return }
        if outlineView.isItemExpanded(item) {
            outlineView.collapseItem(item)
        } else {
            outlineView.expandItem(item)
        }
        outlineView.reloadData(forRowIndexes: IndexSet(integer: row), columnIndexes: IndexSet(integer: 0))
    }
}

extension CalendarListView: NSOutlineViewDataSource {
    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        if item == nil { return accounts.count }
        if let accountId = item as? String {
            return calendarsByAccount[accountId]?.count ?? 0
        }
        return 0
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        if item == nil { return accounts[index].id }
        if let accountId = item as? String {
            return calendarsByAccount[accountId]![index].id
        }
        return ""
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        if let id = item as? String { return accounts.contains(where: { $0.id == id }) }
        return false
    }
}

extension CalendarListView: NSOutlineViewDelegate {
    func outlineView(_ outlineView: NSOutlineView, heightOfRowByItem item: Any) -> CGFloat {
        guard let id = item as? String, accounts.contains(where: { $0.id == id }) else { return 32 }
        let isFirst = accounts.first?.id == id
        return isFirst ? 38 : 38 + 16
    }

    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        guard let id = item as? String else { return nil }
        guard tableColumn?.identifier == Self.contentColId else {
            return NSTableCellView()
        }

        if let account = accounts.first(where: { $0.id == id }) {
            let cell = NSTableCellView()
            let container = HoverableCalendarCell()
            container.translatesAutoresizingMaskIntoConstraints = false
            cell.addSubview(container)

            let label = NSTextField(labelWithString: account.email)
            label.font = .systemFont(ofSize: 12, weight: .medium)
            label.textColor = .secondaryLabelColor
            label.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(label)

            let isExpanded = outlineView.isItemExpanded(id)
            let caret = NSImageView(image: NSImage(systemSymbolName: isExpanded ? "chevron.down" : "chevron.right", accessibilityDescription: nil)!)
            caret.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 10, weight: .medium)
            caret.contentTintColor = .tertiaryLabelColor
            caret.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(caret)

            let hitButton = NSButton()
            hitButton.title = ""
            hitButton.translatesAutoresizingMaskIntoConstraints = false
            hitButton.bezelStyle = .regularSquare
            hitButton.isBordered = false
            hitButton.target = self
            hitButton.action = #selector(accountRowToggled(_:))
            container.addSubview(hitButton)

            let padding: CGFloat = 8
            let topGap: CGFloat = accounts.first?.id == id ? 0 : 16
            NSLayoutConstraint.activate([
                container.topAnchor.constraint(equalTo: cell.topAnchor, constant: topGap),
                container.leadingAnchor.constraint(equalTo: cell.leadingAnchor),
                container.trailingAnchor.constraint(equalTo: cell.trailingAnchor),
                container.bottomAnchor.constraint(equalTo: cell.bottomAnchor),

                label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: padding),
                label.centerYAnchor.constraint(equalTo: container.centerYAnchor),
                caret.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -padding),
                caret.centerYAnchor.constraint(equalTo: label.centerYAnchor),
                hitButton.topAnchor.constraint(equalTo: container.topAnchor),
                hitButton.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                hitButton.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                hitButton.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            ])
            return cell
        }

        let allCalendars = calendarsByAccount.values.flatMap { $0 }
        guard let cal = allCalendars.first(where: { $0.id == id }) else { return nil }

        let cell = NSTableCellView()
        let container = HoverableCalendarCell()
        container.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(container)

        let calColor = GoogleColorMap.color(for: cal.colorHex)

        let colorBox = NSView()
        colorBox.wantsLayer = true
        colorBox.layer?.backgroundColor = calColor.cgColor
        colorBox.layer?.cornerRadius = 6
        colorBox.layer?.borderWidth = 1
        colorBox.layer?.borderColor = calColor.blended(withFraction: 0.1, of: .black)?.cgColor
        colorBox.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(colorBox)

        let checkmark = NSImageView(image: NSImage(systemSymbolName: "checkmark", accessibilityDescription: nil)!)
        checkmark.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 8, weight: .bold)
        checkmark.contentTintColor = .white
        checkmark.translatesAutoresizingMaskIntoConstraints = false
        checkmark.isHidden = !cal.selected
        container.addSubview(checkmark)

        let label = NSTextField(labelWithString: cal.summary)
        label.font = .systemFont(ofSize: 13)
        label.textColor = .secondaryLabelColor
        label.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(label)

        let hitButton = NSButton()
        hitButton.title = ""
        hitButton.translatesAutoresizingMaskIntoConstraints = false
        hitButton.bezelStyle = .regularSquare
        hitButton.isBordered = false
        hitButton.target = self
        hitButton.action = #selector(calendarCheckboxToggled(_:))
        container.addSubview(hitButton)

        let padding: CGFloat = 8
        if cal.isReadOnly {
            let lock = NSImageView(image: NSImage(systemSymbolName: "lock.fill",
                                                   accessibilityDescription: "Read-only")!)
            lock.translatesAutoresizingMaskIntoConstraints = false
            lock.setContentHuggingPriority(.required, for: .horizontal)
            container.addSubview(lock)
            NSLayoutConstraint.activate([
                lock.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -padding),
                lock.centerYAnchor.constraint(equalTo: container.centerYAnchor),
                lock.widthAnchor.constraint(equalToConstant: 12),
                label.trailingAnchor.constraint(lessThanOrEqualTo: lock.leadingAnchor, constant: -4),
            ])
        }

        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: cell.topAnchor),
            container.leadingAnchor.constraint(equalTo: cell.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: cell.trailingAnchor),
            container.bottomAnchor.constraint(equalTo: cell.bottomAnchor),

            colorBox.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: padding),
            colorBox.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            colorBox.widthAnchor.constraint(equalToConstant: 17),
            colorBox.heightAnchor.constraint(equalToConstant: 17),
            checkmark.centerXAnchor.constraint(equalTo: colorBox.centerXAnchor),
            checkmark.centerYAnchor.constraint(equalTo: colorBox.centerYAnchor),
            label.leadingAnchor.constraint(equalTo: colorBox.trailingAnchor, constant: 8),
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            hitButton.topAnchor.constraint(equalTo: container.topAnchor),
            hitButton.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            hitButton.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            hitButton.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        return cell
    }
}
