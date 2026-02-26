import AppKit

class TimeGridView: NSView {
    var displayDate = Date() { didSet { needsDisplay = true } }
    var numberOfColumns = 7 { didSet { needsDisplay = true } }
    var events: [Int: [DisplayEvent]] = [:]

    let hourHeight: CGFloat = 60
    let gutterWidth: CGFloat = 56
    let headerHeight: CGFloat = 50

    private let cal = Calendar.current

    override var isFlipped: Bool { true }

    var totalHeight: CGFloat { headerHeight + hourHeight * 24 }

    var onEventClicked: ((String, NSPoint) -> Void)?
    var onEventDoubleClicked: ((String) -> Void)?
    let dragController = DragController()

    override func mouseDown(with event: NSEvent) {
        let pt = convert(event.locationInWindow, from: nil)
        if event.clickCount == 2 {
            if let (eventId, _) = dragController.hitTestEvent(at: pt, in: self) {
                onEventDoubleClicked?(eventId)
            }
        } else {
            dragController.mouseDown(at: pt, in: self)
        }
    }

    override func mouseDragged(with event: NSEvent) {
        let pt = convert(event.locationInWindow, from: nil)
        dragController.mouseDragged(to: pt, in: self)
    }

    override func mouseUp(with event: NSEvent) {
        let pt = convert(event.locationInWindow, from: nil)
        let dist = hypot(pt.x - dragController.dragStartPoint.x, pt.y - dragController.dragStartPoint.y)
        if dist < 3, event.clickCount == 1 {
            if let (eventId, _) = dragController.hitTestEvent(at: pt, in: self) {
                onEventClicked?(eventId, convert(pt, to: nil))
            }
        }
        dragController.mouseUp(at: pt, in: self)
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.controlBackgroundColor.setFill()
        bounds.fill()

        let contentWidth = bounds.width - gutterWidth
        let colWidth = contentWidth / CGFloat(numberOfColumns)
        let weekStart = weekStartDate()

        drawColumnHeaders(weekStart: weekStart, colWidth: colWidth)
        drawHourLabelsAndLines(colWidth: colWidth)
        drawColumnSeparators(colWidth: colWidth)
        drawCurrentTimeLine(weekStart: weekStart, colWidth: colWidth)
        drawEventBlocks(weekStart: weekStart, colWidth: colWidth)
    }

    func weekStartDate() -> Date {
        if numberOfColumns == 1 {
            return cal.startOfDay(for: displayDate)
        }
        return cal.dateInterval(of: .weekOfYear, for: displayDate)!.start
    }

    private func drawColumnHeaders(weekStart: Date, colWidth: CGFloat) {
        let today = Date()
        for col in 0..<numberOfColumns {
            let colDate = cal.date(byAdding: .day, value: col, to: weekStart)!
            let isToday = cal.isToday(colDate)

            let dayStr: String
            if numberOfColumns == 1 {
                dayStr = colDate.formatted(as: "EEEE, MMM d")
            } else {
                dayStr = colDate.formatted(as: "EEE")
            }
            let dayNum = "\(cal.component(.day, from: colDate))"
            let x = gutterWidth + CGFloat(col) * colWidth

            let nameAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 10, weight: .medium),
                .foregroundColor: isToday ? NSColor.systemRed : NSColor.secondaryLabelColor
            ]
            let nameStr = NSAttributedString(string: dayStr.uppercased(), attributes: nameAttrs)
            let nameSize = nameStr.size()
            nameStr.draw(at: NSPoint(x: x + colWidth / 2 - nameSize.width / 2, y: 6))

            if numberOfColumns > 1 {
                let numAttrs: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: 18, weight: isToday ? .bold : .regular),
                    .foregroundColor: isToday ? NSColor.white : NSColor.labelColor
                ]
                let numStr = NSAttributedString(string: dayNum, attributes: numAttrs)
                let numSize = numStr.size()
                let cx = x + colWidth / 2
                let cy: CGFloat = 30

                if isToday {
                    let r: CGFloat = 14
                    NSColor.systemRed.setFill()
                    NSBezierPath(ovalIn: NSRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)).fill()
                }
                numStr.draw(at: NSPoint(x: cx - numSize.width / 2, y: cy - numSize.height / 2))
            }
        }

        NSColor.separatorColor.setStroke()
        NSBezierPath.strokeLine(from: NSPoint(x: gutterWidth, y: headerHeight),
                                to: NSPoint(x: bounds.width, y: headerHeight))
    }

    private func drawHourLabelsAndLines(colWidth: CGFloat) {
        NSColor.separatorColor.withAlphaComponent(0.5).setStroke()
        let hourFont = NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .regular)
        let hourColor = NSColor.tertiaryLabelColor

        for hour in 0...23 {
            let y = headerHeight + CGFloat(hour) * hourHeight
            let label = hourLabel(hour)
            let attrs: [NSAttributedString.Key: Any] = [.font: hourFont, .foregroundColor: hourColor]
            let s = NSAttributedString(string: label, attributes: attrs)
            let sz = s.size()
            s.draw(at: NSPoint(x: gutterWidth - sz.width - 6, y: y - sz.height / 2))

            let line = NSBezierPath()
            line.move(to: NSPoint(x: gutterWidth, y: y))
            line.line(to: NSPoint(x: bounds.width, y: y))
            line.stroke()
        }
    }

    private func drawColumnSeparators(colWidth: CGFloat) {
        NSColor.separatorColor.withAlphaComponent(0.3).setStroke()
        for col in 0...numberOfColumns {
            let x = gutterWidth + CGFloat(col) * colWidth
            NSBezierPath.strokeLine(from: NSPoint(x: x, y: headerHeight),
                                    to: NSPoint(x: x, y: bounds.height))
        }
    }

    private func drawCurrentTimeLine(weekStart: Date, colWidth: CGFloat) {
        let now = Date()
        let endDate = cal.date(byAdding: .day, value: numberOfColumns, to: weekStart)!
        guard now >= weekStart, now < endDate else { return }

        let dayOffset = cal.dateComponents([.day], from: weekStart, to: now).day ?? 0
        let comps = cal.dateComponents([.hour, .minute], from: now)
        let minutesSinceMidnight = CGFloat(comps.hour! * 60 + comps.minute!)
        let y = headerHeight + (minutesSinceMidnight / 60.0) * hourHeight
        let x = gutterWidth + CGFloat(dayOffset) * colWidth

        NSColor.systemRed.setFill()
        NSColor.systemRed.setStroke()

        let dotSize: CGFloat = 8
        NSBezierPath(ovalIn: NSRect(x: x - dotSize / 2, y: y - dotSize / 2,
                                     width: dotSize, height: dotSize)).fill()
        let line = NSBezierPath()
        line.lineWidth = 1.5
        line.move(to: NSPoint(x: x, y: y))
        line.line(to: NSPoint(x: x + colWidth, y: y))
        line.stroke()
    }

    private func drawEventBlocks(weekStart: Date, colWidth: CGFloat) {
        for (col, dayEvents) in events {
            for event in dayEvents where !event.isAllDay {
                let startComps = cal.dateComponents([.hour, .minute], from: event.start)
                let endComps = cal.dateComponents([.hour, .minute], from: event.end)
                let startY = headerHeight + CGFloat(startComps.hour! * 60 + startComps.minute!) / 60.0 * hourHeight
                let endY = headerHeight + CGFloat(endComps.hour! * 60 + endComps.minute!) / 60.0 * hourHeight
                let x = gutterWidth + CGFloat(col) * colWidth + 1

                let rect = NSRect(x: x, y: startY, width: colWidth - 2, height: max(endY - startY, hourHeight / 4))
                event.color.withAlphaComponent(0.15).setFill()
                let path = NSBezierPath(roundedRect: rect, xRadius: 4, yRadius: 4)
                path.fill()

                event.color.setFill()
                NSBezierPath(rect: NSRect(x: x, y: startY, width: 3, height: rect.height)).fill()

                let attrs: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: 11, weight: .medium),
                    .foregroundColor: event.color
                ]
                let title = NSAttributedString(string: event.title, attributes: attrs)
                title.draw(in: rect.insetBy(dx: 6, dy: 2))
            }
        }
    }

    private func hourLabel(_ hour: Int) -> String {
        switch hour {
        case 0: return "12 AM"
        case 1...11: return "\(hour) AM"
        case 12: return "12 PM"
        default: return "\(hour - 12) PM"
        }
    }
}
