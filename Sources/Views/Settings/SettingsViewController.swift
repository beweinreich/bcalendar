import AppKit

final class SettingsViewController: NSViewController {
    private let tabView = NSTabView()
    private let accountsVC = AccountsSettingsViewController()
    private let apiLogVC = APIRequestLogViewController()
    private let offlineQueueVC = OfflineQueueViewController()

    override func loadView() {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 700, height: 500))
        container.wantsLayer = true

        tabView.translatesAutoresizingMaskIntoConstraints = false
        tabView.tabViewType = .topTabsBezelBorder
        tabView.controlSize = .regular

        let accountsItem = NSTabViewItem(identifier: "accounts")
        accountsItem.label = "Accounts"
        accountsItem.viewController = accountsVC
        tabView.addTabViewItem(accountsItem)

        let generalItem = NSTabViewItem(identifier: "general")
        generalItem.label = "General"
        generalItem.view = placeholderView(title: "General")
        tabView.addTabViewItem(generalItem)

        let alertsItem = NSTabViewItem(identifier: "alerts")
        alertsItem.label = "Alerts"
        alertsItem.view = placeholderView(title: "Alerts")
        tabView.addTabViewItem(alertsItem)

        let apiLogItem = NSTabViewItem(identifier: "apiLog")
        apiLogItem.label = "API Log"
        apiLogItem.viewController = apiLogVC
        tabView.addTabViewItem(apiLogItem)

        let offlineQueueItem = NSTabViewItem(identifier: "offlineQueue")
        offlineQueueItem.label = "Offline Queue"
        offlineQueueItem.viewController = offlineQueueVC
        tabView.addTabViewItem(offlineQueueItem)

        tabView.selectTabViewItem(accountsItem)
        container.addSubview(tabView)

        NSLayoutConstraint.activate([
            tabView.topAnchor.constraint(equalTo: container.topAnchor),
            tabView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            tabView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            tabView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        view = container
    }

    private func placeholderView(title: String) -> NSView {
        let v = NSView()
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 14)
        label.textColor = .secondaryLabelColor
        label.translatesAutoresizingMaskIntoConstraints = false
        v.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: v.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: v.centerYAnchor),
        ])
        return v
    }
}
