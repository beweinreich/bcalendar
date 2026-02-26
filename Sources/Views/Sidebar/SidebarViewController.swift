import AppKit

class SidebarViewController: NSViewController {
    let miniMonth = MiniMonthView()
    private let calendarList = CalendarListView()
    var onDateSelected: ((Date) -> Void)?

    override func loadView() {
        let container = NSView()
        container.wantsLayer = true

        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true

        let stack = NSStackView(views: [miniMonth, calendarList])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 20
        stack.edgeInsets = NSEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        stack.translatesAutoresizingMaskIntoConstraints = false

        scrollView.documentView = stack
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: container.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: container.bottomAnchor),

            stack.widthAnchor.constraint(equalTo: scrollView.contentView.widthAnchor),

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
