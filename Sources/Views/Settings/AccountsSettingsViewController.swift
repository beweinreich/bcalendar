import AppKit

final class AccountsSettingsViewController: NSViewController {
    private let splitView = NSSplitView()
    private let listContainer = NSView()
    private let tableView = NSTableView()
    private let scrollView = NSScrollView()
    private let addButton = NSButton()
    private let removeButton = NSButton()
    private let detailContainer = NSView()
    private let detailStack = NSStackView()

    private var accounts: [Account] = []
    private var selectedAccount: Account?

    override func loadView() {
        let container = NSView()
        container.wantsLayer = true

        splitView.translatesAutoresizingMaskIntoConstraints = false
        splitView.isVertical = true
        splitView.dividerStyle = .thin

        listContainer.translatesAutoresizingMaskIntoConstraints = false
        detailContainer.translatesAutoresizingMaskIntoConstraints = false

        setupListPane()
        setupDetailPane()
        splitView.addArrangedSubview(listContainer)
        splitView.addArrangedSubview(detailContainer)
        splitView.setHoldingPriority(.defaultLow, forSubviewAt: 0)
        splitView.setHoldingPriority(.defaultHigh, forSubviewAt: 1)
        splitView.setPosition(220, ofDividerAt: 0)

        container.addSubview(splitView)

        NSLayoutConstraint.activate([
            splitView.topAnchor.constraint(equalTo: container.topAnchor),
            splitView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            splitView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            splitView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        view = container

        NotificationCenter.default.addObserver(
            self, selector: #selector(reload),
            name: .calendarsChanged, object: nil
        )
        reload()
    }

    private func setupListPane() {
        let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("account"))
        col.title = ""
        col.width = 200
        tableView.addTableColumn(col)
        tableView.headerView = nil
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = 44
        tableView.backgroundColor = .clear
        tableView.selectionHighlightStyle = .regular

        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        listContainer.addSubview(scrollView)

        let buttonStack = NSStackView(views: [addButton, removeButton])
        buttonStack.orientation = .horizontal
        buttonStack.spacing = 4
        buttonStack.translatesAutoresizingMaskIntoConstraints = false
        listContainer.addSubview(buttonStack)

        addButton.title = ""
        addButton.image = NSImage(systemSymbolName: "plus", accessibilityDescription: "Add")!
        addButton.bezelStyle = .rounded
        addButton.target = self
        addButton.action = #selector(addAccount)

        removeButton.title = ""
        removeButton.image = NSImage(systemSymbolName: "minus", accessibilityDescription: "Remove")!
        removeButton.bezelStyle = .rounded
        removeButton.target = self
        removeButton.action = #selector(removeAccount)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: listContainer.topAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: listContainer.leadingAnchor, constant: 8),
            scrollView.trailingAnchor.constraint(equalTo: listContainer.trailingAnchor, constant: -8),
            scrollView.bottomAnchor.constraint(equalTo: buttonStack.topAnchor, constant: -8),
            buttonStack.leadingAnchor.constraint(equalTo: listContainer.leadingAnchor, constant: 8),
            buttonStack.bottomAnchor.constraint(equalTo: listContainer.bottomAnchor, constant: -12),
        ])

        listContainer.setContentHuggingPriority(.defaultLow, for: .horizontal)
    }

    private func setupDetailPane() {
        detailStack.orientation = .vertical
        detailStack.alignment = .leading
        detailStack.spacing = 12
        detailStack.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        detailStack.translatesAutoresizingMaskIntoConstraints = false
        detailContainer.addSubview(detailStack)

        NSLayoutConstraint.activate([
            detailStack.topAnchor.constraint(equalTo: detailContainer.topAnchor),
            detailStack.leadingAnchor.constraint(equalTo: detailContainer.leadingAnchor),
            detailStack.trailingAnchor.constraint(equalTo: detailContainer.trailingAnchor),
        ])
    }

    @objc private func reload() {
        let db = DatabaseManager.shared.pool
        accounts = (try? AccountStore(db: db).all()) ?? []
        tableView.reloadData()

        let idx: Int
        if let sel = selectedAccount, let i = accounts.firstIndex(where: { $0.id == sel.id }) {
            idx = i
        } else {
            selectedAccount = accounts.first
            idx = accounts.isEmpty ? -1 : 0
        }
        if idx >= 0 {
            tableView.selectRowIndexes(IndexSet(integer: idx), byExtendingSelection: false)
        } else {
            tableView.deselectAll(nil)
        }
        updateDetailPanel()
        updateRemoveButton()
    }

    private func updateDetailPanel() {
        detailStack.arrangedSubviews.forEach { $0.removeFromSuperview() }

        guard let account = selectedAccount else {
            let label = NSTextField(labelWithString: "Select an account")
            label.textColor = .secondaryLabelColor
            detailStack.addArrangedSubview(label)
            return
        }

        let enableCheck = NSButton(checkboxWithTitle: "Enable this account", target: nil, action: nil)
        enableCheck.state = .on
        detailStack.addArrangedSubview(enableCheck)

        let descLabel = NSTextField(labelWithString: "Description:")
        descLabel.font = .systemFont(ofSize: 12)
        let descField = NSTextField(string: account.displayName.isEmpty ? account.email : account.displayName)
        descField.isEditable = false
        descField.isBordered = true
        descField.preferredMaxLayoutWidth = 280
        descField.translatesAutoresizingMaskIntoConstraints = false
        descField.widthAnchor.constraint(greaterThanOrEqualToConstant: 200).isActive = true
        detailStack.addArrangedSubview(descLabel)
        detailStack.addArrangedSubview(descField)

        let userLabel = NSTextField(labelWithString: "User Name:")
        userLabel.font = .systemFont(ofSize: 12)
        let userField = NSTextField(string: account.email)
        userField.isEditable = false
        userField.isBordered = true
        userField.preferredMaxLayoutWidth = 280
        userField.translatesAutoresizingMaskIntoConstraints = false
        userField.widthAnchor.constraint(greaterThanOrEqualToConstant: 200).isActive = true
        detailStack.addArrangedSubview(userLabel)
        detailStack.addArrangedSubview(userField)

        let refreshLabel = NSTextField(labelWithString: "Refresh Calendars:")
        refreshLabel.font = .systemFont(ofSize: 12)
        let refreshPop = NSPopUpButton(frame: .zero, pullsDown: false)
        refreshPop.addItems(withTitles: ["Every 5 minutes", "Every 15 minutes", "Every 30 minutes", "Every hour"])
        refreshPop.selectItem(at: 1)
        refreshPop.isEnabled = false
        detailStack.addArrangedSubview(refreshLabel)
        detailStack.addArrangedSubview(refreshPop)
    }

    private func updateRemoveButton() {
        removeButton.isEnabled = selectedAccount != nil
    }

    @objc private func addAccount() {
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
                await MainActor.run {
                    NotificationCenter.default.post(name: .calendarsChanged, object: nil)
                }
            } catch {
                await MainActor.run {
                    let alert = NSAlert(error: error)
                    alert.runModal()
                }
            }
        }
    }

    @objc private func removeAccount() {
        guard let account = selectedAccount else { return }

        let alert = NSAlert()
        alert.messageText = "Remove Account"
        alert.informativeText = "Remove \(account.displayName.isEmpty ? account.email : account.displayName)? Calendars from this account will be removed."
        alert.addButton(withTitle: "Remove")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning

        if alert.runModal() == .alertFirstButtonReturn {
            let db = DatabaseManager.shared.pool
            try? CalendarStore(db: db).deleteForAccount(account.id)
            try? AccountStore(db: db).delete(account.id)
            OAuthToken.delete(accountId: account.id)
            selectedAccount = nil
            NotificationCenter.default.post(name: .calendarsChanged, object: nil)
        }
    }
}

extension AccountsSettingsViewController: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int { accounts.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let account = accounts[row]
        let cell = NSTableCellView()

        let icon = NSImageView(image: NSImage(systemSymbolName: "person.circle.fill", accessibilityDescription: nil)!)
        icon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        icon.contentTintColor = .systemBlue
        icon.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(icon)

        let nameLabel = NSTextField(labelWithString: account.displayName.isEmpty ? account.email : account.displayName)
        nameLabel.font = .systemFont(ofSize: 13, weight: .medium)
        nameLabel.lineBreakMode = .byTruncatingTail
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(nameLabel)

        let typeLabel = NSTextField(labelWithString: "CalDAV")
        typeLabel.font = .systemFont(ofSize: 11)
        typeLabel.textColor = .secondaryLabelColor
        typeLabel.translatesAutoresizingMaskIntoConstraints = false
        cell.addSubview(typeLabel)

        NSLayoutConstraint.activate([
            icon.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
            icon.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 20),
            nameLabel.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 8),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: cell.trailingAnchor, constant: -4),
            nameLabel.topAnchor.constraint(equalTo: cell.topAnchor, constant: 6),
            typeLabel.leadingAnchor.constraint(equalTo: nameLabel.leadingAnchor),
            typeLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2),
        ])

        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        let row = tableView.selectedRow
        selectedAccount = row >= 0 ? accounts[row] : nil
        updateDetailPanel()
        updateRemoveButton()
    }
}
