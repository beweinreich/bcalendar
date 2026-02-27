import AppKit

private class SidebarContainerView: NSView {
    private static let darkSidebarGray = NSColor(red: 0x35/255, green: 0x35/255, blue: 0x35/255, alpha: 1)
    override var wantsUpdateLayer: Bool { true }
    override func updateLayer() {
        let isDark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        layer?.backgroundColor = (isDark ? Self.darkSidebarGray : NSColor.windowBackgroundColor).cgColor
    }
}

class SidebarViewController: NSViewController {
    let miniMonth = MiniMonthView()
    private let calendarList = CalendarListView()
    var onDateSelected: ((Date) -> Void)?

    override func loadView() {
        let container = SidebarContainerView()
        container.wantsLayer = true

        let stack = NSStackView(views: [calendarList, miniMonth])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 20
        stack.edgeInsets = NSEdgeInsets(top: 16, left: 14, bottom: 14, right: 14)
        stack.distribution = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(stack)

        miniMonth.setContentHuggingPriority(.defaultHigh, for: .vertical)
        calendarList.setContentHuggingPriority(.defaultLow, for: .vertical)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: container.topAnchor),
            stack.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: container.bottomAnchor),

            miniMonth.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -28),
            miniMonth.heightAnchor.constraint(equalToConstant: 172),
            calendarList.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -28),
        ])

        view = container

        miniMonth.onDateSelected = { [weak self] date in
            self?.onDateSelected?(date)
        }
    }
}
