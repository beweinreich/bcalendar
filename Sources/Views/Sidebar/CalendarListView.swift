import AppKit

class CalendarListView: NSView {
    private let outlineView = NSOutlineView()
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

    private func setup() {
        let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("cal"))
        col.title = ""
        outlineView.addTableColumn(col)
        outlineView.outlineTableColumn = col
        outlineView.headerView = nil
        outlineView.dataSource = self
        outlineView.delegate = self
        outlineView.rowHeight = 24
        outlineView.indentationPerLevel = 16

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
    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        guard let id = item as? String else { return nil }

        if let account = accounts.first(where: { $0.id == id }) {
            let cell = NSTableCellView()
            let label = NSTextField(labelWithString: account.displayName.isEmpty ? account.email : account.displayName)
            label.font = .systemFont(ofSize: 12, weight: .semibold)
            label.translatesAutoresizingMaskIntoConstraints = false
            cell.addSubview(label)
            NSLayoutConstraint.activate([
                label.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 18),
                label.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            ])
            return cell
        }

        let allCalendars = calendarsByAccount.values.flatMap { $0 }
        guard let cal = allCalendars.first(where: { $0.id == id }) else { return nil }

        let cell = NSTableCellView()

        let checkbox = NSButton(checkboxWithTitle: cal.summary, target: self,
                                action: #selector(calendarCheckboxToggled(_:)))
        checkbox.state = cal.selected ? .on : .off
        checkbox.font = .systemFont(ofSize: 12)
        checkbox.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(checkbox)

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
            checkbox.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
            checkbox.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
        ])

        return cell
    }
}
