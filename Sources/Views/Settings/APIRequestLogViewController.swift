import AppKit

final class APIRequestLogViewController: NSViewController {
    private let scrollView = NSScrollView()
    private let tableView = NSTableView()
    private let clearButton = NSButton()

    private var entries: [APIRequestLogEntry] = []
    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    override func loadView() {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 700, height: 500))
        container.wantsLayer = true

        for (id, title, width) in [("time", "Time", 70), ("op", "Operation", 70), ("method", "Method", 60),
                                    ("status", "Status", 50), ("path", "Path", 200), ("error", "Error", 200)] {
            let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(id))
            col.title = title
            col.width = CGFloat(width)
            tableView.addTableColumn(col)
        }
        tableView.headerView = NSTableHeaderView()
        tableView.dataSource = self
        tableView.rowHeight = 22

        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(scrollView)

        clearButton.title = "Clear Log"
        clearButton.bezelStyle = .rounded
        clearButton.target = self
        clearButton.action = #selector(clearTapped)
        clearButton.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(clearButton)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8),
            scrollView.bottomAnchor.constraint(equalTo: clearButton.topAnchor, constant: -8),
            clearButton.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
            clearButton.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -8),
        ])

        view = container

        NotificationCenter.default.addObserver(
            self, selector: #selector(reload),
            name: .apiRequestLogChanged, object: nil
        )
        reload()
    }

    @objc private func reload() {
        entries = APIRequestLogger.shared.getEntries()
        tableView.reloadData()
    }

    @objc private func clearTapped() {
        APIRequestLogger.shared.clear()
    }
}

extension APIRequestLogViewController: NSTableViewDataSource {
    func numberOfRows(in tableView: NSTableView) -> Int {
        entries.count
    }

    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        guard row < entries.count else { return nil }
        let e = entries[row]
        switch tableColumn?.identifier.rawValue {
        case "time": return dateFormatter.string(from: e.timestamp)
        case "op": return e.operation
        case "method": return e.method
        case "status": return e.statusCode
        case "path": return e.path
        case "error": return e.errorMessage.map { String($0.prefix(100)) }
        default: return nil
        }
    }
}
