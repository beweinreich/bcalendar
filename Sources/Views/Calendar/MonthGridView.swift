import AppKit

class MonthGridViewController: NSViewController {
    private let containerView = SwipeableView()
    private let monthView = MonthGridView()

    var onSwipeLeft: (() -> Void)? {
        didSet { containerView.onSwipeLeft = onSwipeLeft }
    }
    var onSwipeRight: (() -> Void)? {
        didSet { containerView.onSwipeRight = onSwipeRight }
    }

    override func loadView() {
        containerView.wantsLayer = true
        monthView.translatesAutoresizingMaskIntoConstraints = false
        
        containerView.addSubview(monthView)
        
        NSLayoutConstraint.activate([
            monthView.topAnchor.constraint(equalTo: containerView.topAnchor),
            monthView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            monthView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            monthView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
        
        view = containerView
    }

    func update(date: Date, events: [[DisplayEvent]] = []) {
        monthView.displayDate = date
        monthView.events = events
    }
}

class MonthGridView: NSView {
    var displayDate = Date() { didSet { needsDisplay = true } }
    var events: [[DisplayEvent]] = [] { didSet { needsDisplay = true } }

    private let cal = Calendar.current
    private let dayNames = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    private let headerHeight: CGFloat = 32

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.controlBackgroundColor.setFill()
        bounds.fill()

        let (firstOfMonth, daysInMonth, startWeekday) = cal.monthGrid(for: displayDate)
        let totalSlots = startWeekday - 1 + daysInMonth
        let rows = Int(ceil(Double(totalSlots) / 7.0))
        let cellW = bounds.width / 7
        let cellH = (bounds.height - headerHeight) / CGFloat(rows)

        drawDayHeaders(cellWidth: cellW)
        drawGrid(rows: rows, cellWidth: cellW, cellHeight: cellH)
        drawDayNumbers(firstOfMonth: firstOfMonth, daysInMonth: daysInMonth,
                       startWeekday: startWeekday, cellWidth: cellW, cellHeight: cellH)
        drawEventPills(startWeekday: startWeekday, cellWidth: cellW, cellHeight: cellH)
    }

    private func drawDayHeaders(cellWidth: CGFloat) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: .medium),
            .foregroundColor: NSColor.secondaryLabelColor,
            .kern: 0.4
        ]
        for (i, name) in dayNames.enumerated() {
            let s = NSAttributedString(string: name, attributes: attrs)
            let sz = s.size()
            s.draw(at: NSPoint(x: CGFloat(i) * cellWidth + cellWidth / 2 - sz.width / 2,
                               y: (headerHeight - sz.height) / 2))
        }
    }

    private func drawGrid(rows: Int, cellWidth: CGFloat, cellHeight: CGFloat) {
        NSColor.separatorColor.withAlphaComponent(0.07).setStroke()
        for col in 0...7 {
            let x = CGFloat(col) * cellWidth
            NSBezierPath.strokeLine(from: NSPoint(x: x, y: headerHeight),
                                    to: NSPoint(x: x, y: bounds.height))
        }
        NSColor.separatorColor.withAlphaComponent(0.12).setStroke()
        for row in 0...rows {
            let y = headerHeight + CGFloat(row) * cellHeight
            NSBezierPath.strokeLine(from: NSPoint(x: 0, y: y),
                                    to: NSPoint(x: bounds.width, y: y))
        }
    }

    private func drawDayNumbers(firstOfMonth: Date, daysInMonth: Int, startWeekday: Int,
                                 cellWidth: CGFloat, cellHeight: CGFloat) {
        for day in 1...daysInMonth {
            let offset = startWeekday - 1 + day - 1
            let col = offset % 7
            let row = offset / 7
            let x = CGFloat(col) * cellWidth
            let y = headerHeight + CGFloat(row) * cellHeight

            let dayDate = cal.date(byAdding: .day, value: day - 1, to: firstOfMonth)!
            let isToday = cal.isToday(dayDate)

            if isToday {
                let sz: CGFloat = 22
                NSColor.systemRed.setFill()
                NSBezierPath(ovalIn: NSRect(x: x + cellWidth / 2 - sz / 2, y: y + 4,
                                            width: sz, height: sz)).fill()
            }

            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 13, weight: isToday ? .bold : .regular),
                .foregroundColor: isToday ? NSColor.white : NSColor.labelColor
            ]
            let s = NSAttributedString(string: "\(day)", attributes: attrs)
            let sz = s.size()
            s.draw(at: NSPoint(x: x + cellWidth / 2 - sz.width / 2, y: y + 4 + 11 - sz.height / 2))
        }
    }

    private func drawEventPills(startWeekday: Int, cellWidth: CGFloat, cellHeight: CGFloat) {
        for (dayIndex, dayEvents) in events.enumerated() {
            let offset = startWeekday - 1 + dayIndex
            let col = offset % 7
            let row = offset / 7
            let x = CGFloat(col) * cellWidth + 3
            let baseY = headerHeight + CGFloat(row) * cellHeight + 30

            for (i, event) in dayEvents.prefix(3).enumerated() {
                let pillY = baseY + CGFloat(i) * 18
                let pillRect = NSRect(x: x, y: pillY, width: cellWidth - 6, height: 15)
                event.color.pastel.setFill()
                NSBezierPath(roundedRect: pillRect, xRadius: 7.5, yRadius: 7.5).fill()

                let titleColor = event.color
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: 10, weight: .medium),
                    .foregroundColor: titleColor
                ]
                NSAttributedString(string: event.title, attributes: attrs)
                    .draw(in: pillRect.insetBy(dx: 7, dy: 1))
            }
        }
    }
}

struct DisplayEvent {
    let id: String
    let title: String
    let start: Date
    let end: Date
    let isAllDay: Bool
    let color: NSColor
    let calendarID: String
}
