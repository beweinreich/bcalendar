import AppKit

private class NoDisclosureOutlineView: NSOutlineView {
    override func frameOfOutlineCell(atRow row: Int) -> NSRect { .zero }
}

class CalendarListView: NSView {
    private let outlineView = NoDisclosureOutlineView()
    private let scrollView = NSScrollView()
    private let addButton = NSButton()
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

        scrollView.documentView = outlineView
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scrollView)

        addButton.title = "Add Account…"
        addButton.bezelStyle = .accessoryBarAction
        addButton.target = self
        addButton.action = #selector(addAccountClicked)
        addButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(addButton)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            addButton.topAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: 8),
            addButton.leadingAnchor.constraint(equalTo: leadingAnchor),
            addButton.bottomAnchor.constraint(equalTo: bottomAnchor),
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
        if accounts.contains(where: { $0.id == item as? String }) { return 38 }
        return 24
    }

    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        guard let id = item as? String else { return nil }
        guard tableColumn?.identifier == Self.contentColId else {
            return NSTableCellView()
        }

        if let account = accounts.first(where: { $0.id == id }) {
            let cell = NSTableCellView()
            let label = NSTextField(labelWithString: account.email)
            label.font = .systemFont(ofSize: 12, weight: .semibold)
            label.translatesAutoresizingMaskIntoConstraints = false
            cell.addSubview(label)

            let isExpanded = outlineView.isItemExpanded(id)
            let caret = NSImageView(image: NSImage(systemSymbolName: isExpanded ? "chevron.down" : "chevron.right", accessibilityDescription: nil)!)
            caret.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 10, weight: .medium)
            caret.contentTintColor = .secondaryLabelColor
            caret.translatesAutoresizingMaskIntoConstraints = false
            cell.addSubview(caret)

            let hitButton = NSButton()
            hitButton.title = ""
            hitButton.translatesAutoresizingMaskIntoConstraints = false
            hitButton.bezelStyle = .regularSquare
            hitButton.isBordered = false
            hitButton.target = self
            hitButton.action = #selector(accountRowToggled(_:))
            cell.addSubview(hitButton)

            NSLayoutConstraint.activate([
                label.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 2),
                label.topAnchor.constraint(equalTo: cell.topAnchor, constant: 14),
                caret.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
                caret.centerYAnchor.constraint(equalTo: label.centerYAnchor),
                hitButton.topAnchor.constraint(equalTo: cell.topAnchor),
                hitButton.leadingAnchor.constraint(equalTo: cell.leadingAnchor),
                hitButton.trailingAnchor.constraint(equalTo: cell.trailingAnchor),
                hitButton.bottomAnchor.constraint(equalTo: cell.bottomAnchor),
            ])
            return cell
        }

        let allCalendars = calendarsByAccount.values.flatMap { $0 }
        guard let cal = allCalendars.first(where: { $0.id == id }) else { return nil }

        let cell = NSTableCellView()

        let colorBox = NSView()
        colorBox.wantsLayer = true
        colorBox.layer?.backgroundColor = GoogleColorMap.color(for: cal.colorHex).cgColor
        colorBox.layer?.cornerRadius = 4
        colorBox.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(colorBox)

        let checkmark = NSImageView(image: NSImage(systemSymbolName: "checkmark", accessibilityDescription: nil)!)
        checkmark.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 10, weight: .bold)
        checkmark.contentTintColor = .white
        checkmark.translatesAutoresizingMaskIntoConstraints = false
        checkmark.isHidden = !cal.selected
        cell.addSubview(checkmark)

        let label = NSTextField(labelWithString: cal.summary)
        label.font = .systemFont(ofSize: 12)
        label.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(label)

        let hitButton = NSButton()
        hitButton.title = ""
        hitButton.translatesAutoresizingMaskIntoConstraints = false
        hitButton.bezelStyle = .regularSquare
        hitButton.isBordered = false
        hitButton.target = self
        hitButton.action = #selector(calendarCheckboxToggled(_:))
        cell.addSubview(hitButton)

        if cal.isReadOnly {
            let lock = NSImageView(image: NSImage(systemSymbolName: "lock.fill",
                                                   accessibilityDescription: "Read-only")!)
            lock.translatesAutoresizingMaskIntoConstraints = false
            lock.setContentHuggingPriority(.required, for: .horizontal)
            cell.addSubview(lock)
            NSLayoutConstraint.activate([
                lock.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
                lock.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                lock.widthAnchor.constraint(equalToConstant: 12),
            ])
        }

        NSLayoutConstraint.activate([
            colorBox.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 2),
            colorBox.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            colorBox.widthAnchor.constraint(equalToConstant: 18),
            colorBox.heightAnchor.constraint(equalToConstant: 18),
            checkmark.centerXAnchor.constraint(equalTo: colorBox.centerXAnchor),
            checkmark.centerYAnchor.constraint(equalTo: colorBox.centerYAnchor),
            label.leadingAnchor.constraint(equalTo: colorBox.trailingAnchor, constant: 6),
            label.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            hitButton.topAnchor.constraint(equalTo: cell.topAnchor),
            hitButton.leadingAnchor.constraint(equalTo: cell.leadingAnchor),
            hitButton.trailingAnchor.constraint(equalTo: cell.trailingAnchor),
            hitButton.bottomAnchor.constraint(equalTo: cell.bottomAnchor),
        ])

        return cell
    }
}

