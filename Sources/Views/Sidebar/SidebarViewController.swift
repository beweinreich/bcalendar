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

        let miniMonthContainer = NSView()
        miniMonthContainer.translatesAutoresizingMaskIntoConstraints = false
        miniMonth.translatesAutoresizingMaskIntoConstraints = false
        miniMonthContainer.addSubview(miniMonth)

        let calendarListContainer = NSView()
        calendarListContainer.translatesAutoresizingMaskIntoConstraints = false
        calendarList.translatesAutoresizingMaskIntoConstraints = false
        calendarListContainer.addSubview(calendarList)

        container.addSubview(miniMonthContainer)
        container.addSubview(calendarListContainer)

        let padding: CGFloat = 8
        let gapBelowCalendar: CGFloat = 12
        NSLayoutConstraint.activate([
            miniMonthContainer.topAnchor.constraint(equalTo: container.topAnchor, constant: 32),
            miniMonthContainer.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            miniMonthContainer.trailingAnchor.constraint(equalTo: container.trailingAnchor),

            miniMonth.topAnchor.constraint(equalTo: miniMonthContainer.topAnchor, constant: padding),
            miniMonth.leadingAnchor.constraint(equalTo: miniMonthContainer.leadingAnchor, constant: padding),
            miniMonth.trailingAnchor.constraint(equalTo: miniMonthContainer.trailingAnchor, constant: -padding),
            miniMonth.heightAnchor.constraint(equalToConstant: 172),
            miniMonth.bottomAnchor.constraint(equalTo: miniMonthContainer.bottomAnchor, constant: -padding),

            calendarListContainer.topAnchor.constraint(equalTo: miniMonthContainer.bottomAnchor, constant: gapBelowCalendar),
            calendarListContainer.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            calendarListContainer.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            calendarListContainer.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -padding),

            calendarList.topAnchor.constraint(equalTo: calendarListContainer.topAnchor),
            calendarList.leadingAnchor.constraint(equalTo: calendarListContainer.leadingAnchor),
            calendarList.trailingAnchor.constraint(equalTo: calendarListContainer.trailingAnchor),
            calendarList.bottomAnchor.constraint(equalTo: calendarListContainer.bottomAnchor),
        ])

        view = container

        miniMonth.onDateSelected = { [weak self] date in
            self?.onDateSelected?(date)
        }
    }
}
