import AppKit

class SidebarViewController: NSViewController {
    let miniMonth = MiniMonthView()
    private let calendarList = CalendarListView()
    var onDateSelected: ((Date) -> Void)?

    override func loadView() {
        let container = NSView()
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor

        // Calendars at top (scrollable), month view fixed at bottom
        let stack = NSStackView(views: [calendarList, miniMonth])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.edgeInsets = NSEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
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

            miniMonth.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -24),
            miniMonth.heightAnchor.constraint(equalToConstant: 190),
            calendarList.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -24),
        ])

        view = container

        miniMonth.onDateSelected = { [weak self] date in
            self?.onDateSelected?(date)
        }
    }
}
