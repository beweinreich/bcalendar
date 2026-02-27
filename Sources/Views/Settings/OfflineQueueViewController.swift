import AppKit

final class OfflineQueueViewController: NSViewController {
    private let scrollView = NSScrollView()
    private let tableView = NSTableView()
    private let deleteButton = NSButton()

    private var ops: [PendingOp] = []
    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .medium
        return f
    }()

    override func loadView() {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 700, height: 500))
        container.wantsLayer = true

        for (id, title, width) in [("type", "Type", 70), ("summary", "Summary", 150),
                                    ("calendarId", "Calendar", 120), ("created", "Created", 130),
                                    ("retries", "Retries", 50), ("error", "Last Error", 150)] {
            let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(id))
            col.title = title
            col.width = CGFloat(width)
            tableView.addTableColumn(col)
        }
        tableView.headerView = NSTableHeaderView()
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = 22
        tableView.allowsMultipleSelection = true

        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(scrollView)

        let selectAllButton = NSButton(title: "Select All", target: self, action: #selector(selectAllTapped))
        selectAllButton.bezelStyle = .rounded

        deleteButton.title = "Delete"
        deleteButton.bezelStyle = .rounded
        deleteButton.target = self
        deleteButton.action = #selector(deleteTapped)
        deleteButton.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(deleteButton)

        selectAllButton.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(selectAllButton)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8),
            scrollView.bottomAnchor.constraint(equalTo: deleteButton.topAnchor, constant: -8),
            deleteButton.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
            deleteButton.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -8),
            selectAllButton.leadingAnchor.constraint(equalTo: deleteButton.trailingAnchor, constant: 8),
            selectAllButton.centerYAnchor.constraint(equalTo: deleteButton.centerYAnchor),
        ])

        view = container

        NotificationCenter.default.addObserver(
            self, selector: #selector(reload),
            name: .offlineQueueChanged, object: nil
        )
        reload()
    }

    @objc private func reload() {
        ops = OfflineQueue.shared.pendingOps()
        tableView.reloadData()
        updateDeleteButtonState()
    }

    @objc private func selectAllTapped() {
        tableView.selectAll(nil)
        updateDeleteButtonState()
    }

    private func updateDeleteButtonState() {
        deleteButton.isEnabled = !tableView.selectedRowIndexes.isEmpty
    }

    @objc private func deleteTapped() {
        let indexes = tableView.selectedRowIndexes
        guard !indexes.isEmpty else { return }
        let idsToDelete = indexes.filter { $0 < ops.count }.map { ops[$0].id }
        for id in idsToDelete {
            OfflineQueue.shared.removeOp(id: id)
        }
        tableView.deselectAll(nil)
    }
}

extension OfflineQueueViewController: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int {
        ops.count
    }

    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        guard row < ops.count else { return nil }
        let op = ops[row]
        switch tableColumn?.identifier.rawValue {
        case "type": return op.opType.capitalized
        case "summary":
            if let data = op.payloadJSON.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let s = json["summary"] as? String, !s.isEmpty { return s }
            return "—"
        case "calendarId": return String(op.calendarId.prefix(20))
        case "created": return dateFormatter.string(from: op.createdAt)
        case "retries": return op.retryCount
        case "error": return op.lastError.map { String($0.prefix(80)) }
        default: return nil
        }
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        updateDeleteButtonState()
    }
}
