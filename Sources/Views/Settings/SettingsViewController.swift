import AppKit

final class SettingsViewController: NSViewController {
    private let tabView = NSTabView()
    private let accountsVC = AccountsSettingsViewController()

    override func loadView() {
        let container = NSView()
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

        let advancedItem = NSTabViewItem(identifier: "advanced")
        advancedItem.label = "Advanced"
        advancedItem.view = placeholderView(title: "Advanced")
        tabView.addTabViewItem(advancedItem)

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
