import AppKit

class TimeGridHeaderView: NSView {
    var displayDate = Date() { didSet { needsDisplay = true } }
    var numberOfColumns = 7 { didSet { needsDisplay = true } }
    var usesCustomStartDate = false

    let gutterWidth: CGFloat = 56
    let headerHeight: CGFloat = 54

    private let cal = Calendar.current

    override var isFlipped: Bool { true }

    func weekStartDate() -> Date {
        if numberOfColumns == 1 || usesCustomStartDate {
            return cal.startOfDay(for: displayDate)
        }
        return cal.dateInterval(of: .weekOfYear, for: displayDate)!.start
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.controlBackgroundColor.setFill()
        bounds.fill()

        let contentWidth = bounds.width - gutterWidth
        let colWidth = contentWidth / CGFloat(numberOfColumns)
        let weekStart = weekStartDate()

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
                .font: NSFont.systemFont(ofSize: 12, weight: .medium),
                .foregroundColor: isToday ? NSColor.systemRed : NSColor.secondaryLabelColor,
                .kern: 0.4
            ]
            let nameStr = NSAttributedString(string: dayStr.uppercased(), attributes: nameAttrs)
            let nameSize = nameStr.size()
            nameStr.draw(at: NSPoint(x: x + colWidth / 2 - nameSize.width / 2, y: 8))

            if numberOfColumns > 1 {
                let numAttrs: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: 18, weight: isToday ? .bold : .regular),
                    .foregroundColor: isToday ? NSColor.white : NSColor.labelColor
                ]
                let numStr = NSAttributedString(string: dayNum, attributes: numAttrs)
                let numSize = numStr.size()
                let cx = x + colWidth / 2
                let cy: CGFloat = 33

                if isToday {
                    let r: CGFloat = 14
                    NSColor.systemRed.setFill()
                    NSBezierPath(ovalIn: NSRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)).fill()
                }
                numStr.draw(at: NSPoint(x: cx - numSize.width / 2, y: cy - numSize.height / 2))
            }
        }

        NSColor.separatorColor.withAlphaComponent(0.25).setStroke()
        NSBezierPath.strokeLine(from: NSPoint(x: gutterWidth, y: headerHeight),
                                to: NSPoint(x: bounds.width, y: headerHeight))
    }
}

class TimeGridView: NSView {
    var displayDate = Date() { didSet { needsDisplay = true } }
    var numberOfColumns = 7 { didSet { needsDisplay = true } }
    var events: [Int: [DisplayEvent]] = [:]
    var bodyOnly = false { didSet { needsDisplay = true } }
    var usesCustomStartDate = false

    let hourHeight: CGFloat = 66
    let gutterWidth: CGFloat = 56
    let headerHeight: CGFloat = 54

    private let cal = Calendar.current

    override var isFlipped: Bool { true }

    var totalHeight: CGFloat { bodyOnly ? hourHeight * 24 : headerHeight + hourHeight * 24 }

    var onEventDoubleClicked: ((String) -> Void)?
    var onEventDeleteRequested: ((String) -> Void)?
    var selectedEventId: String? { didSet { needsDisplay = true } }
    let dragController = DragController()
    private(set) var eventRects: [(id: String, rect: NSRect)] = []

    /// Rect for an event by id, in view coordinates. Use for popover anchor.
    func rectForEvent(id: String) -> NSRect? {
        eventRects.first(where: { $0.id == id })?.rect
    }

    /// Shown while the create-event popover is open. Cleared when user saves or cancels.
    var pendingCreate: (start: Date, end: Date, column: Int)? { didSet { needsDisplay = true } }

    /// Rect for a new event slot (start, end, column). Use for popover anchor when creating.
    func rectForNewEvent(start: Date, end: Date, column: Int) -> NSRect {
        let cal = Calendar.current
        let startComps = cal.dateComponents([.hour, .minute], from: start)
        let endComps = cal.dateComponents([.hour, .minute], from: end)
        let startY = bodyTopOffset + CGFloat(startComps.hour! * 60 + startComps.minute!) / 60.0 * hourHeight
        let endY = bodyTopOffset + CGFloat(endComps.hour! * 60 + endComps.minute!) / 60.0 * hourHeight
        let height = max(endY - startY - 2, hourHeight / 4)

        let contentWidth = bounds.width - gutterWidth
        let colWidth = contentWidth / CGFloat(numberOfColumns)
        let x = gutterWidth + CGFloat(column) * colWidth + 2
        let w = colWidth - 4

        return NSRect(x: x, y: startY + 1, width: w, height: height)
    }

    override var acceptsFirstResponder: Bool { return true }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 51 || event.keyCode == 117 {
            if let selectedEventId = selectedEventId {
                onEventDeleteRequested?(selectedEventId)
                return
            }
        }
        super.keyDown(with: event)
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        let pt = convert(event.locationInWindow, from: nil)
        
        if let (eventId, _) = dragController.hitTestEvent(at: pt, in: self) {
            selectedEventId = eventId
        } else {
            selectedEventId = nil
        }
        
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
        dragController.mouseUp(at: pt, in: self)
    }

    var bodyTopOffset: CGFloat { bodyOnly ? 0 : headerHeight }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.controlBackgroundColor.setFill()
        bounds.fill()

        let contentWidth = bounds.width - gutterWidth
        let colWidth = contentWidth / CGFloat(numberOfColumns)
        let weekStart = weekStartDate()

        if !bodyOnly {
            drawColumnHeaders(weekStart: weekStart, colWidth: colWidth)
        }
        drawHourLabelsAndLines(colWidth: colWidth)
        drawColumnSeparators(colWidth: colWidth)
        drawCurrentTimeLine(weekStart: weekStart, colWidth: colWidth)
        drawEventBlocks(weekStart: weekStart, colWidth: colWidth)
    }

    func weekStartDate() -> Date {
        if numberOfColumns == 1 || usesCustomStartDate {
            return cal.startOfDay(for: displayDate)
        }
        return cal.dateInterval(of: .weekOfYear, for: displayDate)!.start
    }

    private func drawColumnHeaders(weekStart: Date, colWidth: CGFloat) {
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
                .font: NSFont.systemFont(ofSize: 12, weight: .medium),
                .foregroundColor: isToday ? NSColor.systemRed : NSColor.secondaryLabelColor,
                .kern: 0.4
            ]
            let nameStr = NSAttributedString(string: dayStr.uppercased(), attributes: nameAttrs)
            let nameSize = nameStr.size()
            nameStr.draw(at: NSPoint(x: x + colWidth / 2 - nameSize.width / 2, y: 8))

            if numberOfColumns > 1 {
                let numAttrs: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: 18, weight: isToday ? .bold : .regular),
                    .foregroundColor: isToday ? NSColor.white : NSColor.labelColor
                ]
                let numStr = NSAttributedString(string: dayNum, attributes: numAttrs)
                let numSize = numStr.size()
                let cx = x + colWidth / 2
                let cy: CGFloat = 33

                if isToday {
                    let r: CGFloat = 14
                    NSColor.systemRed.setFill()
                    NSBezierPath(ovalIn: NSRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)).fill()
                }
                numStr.draw(at: NSPoint(x: cx - numSize.width / 2, y: cy - numSize.height / 2))
            }
        }

        NSColor.separatorColor.withAlphaComponent(0.25).setStroke()
        NSBezierPath.strokeLine(from: NSPoint(x: gutterWidth, y: headerHeight),
                                to: NSPoint(x: bounds.width, y: headerHeight))
    }

    private func drawHourLabelsAndLines(colWidth: CGFloat) {
        let hourFont = NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .regular)
        let hourColor = NSColor.tertiaryLabelColor

        for hour in 0...23 {
            let y = bodyTopOffset + CGFloat(hour) * hourHeight
            let label = hourLabel(hour)
            let attrs: [NSAttributedString.Key: Any] = [.font: hourFont, .foregroundColor: hourColor]
            let s = NSAttributedString(string: label, attributes: attrs)
            let sz = s.size()
            s.draw(at: NSPoint(x: gutterWidth - sz.width - 6, y: y - sz.height / 2))

            NSColor.separatorColor.withAlphaComponent(0.12).setStroke()
            let line = NSBezierPath()
            line.lineWidth = 0.5
            line.move(to: NSPoint(x: gutterWidth, y: y))
            line.line(to: NSPoint(x: bounds.width, y: y))
            line.stroke()
        }
    }

    private func drawColumnSeparators(colWidth: CGFloat) {
        NSColor.separatorColor.withAlphaComponent(0.07).setStroke()
        for col in 0...numberOfColumns {
            let x = gutterWidth + CGFloat(col) * colWidth
            NSBezierPath.strokeLine(from: NSPoint(x: x, y: bodyTopOffset),
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
        let y = bodyTopOffset + (minutesSinceMidnight / 60.0) * hourHeight
        let x = gutterWidth + CGFloat(dayOffset) * colWidth

        let mutedRed = NSColor.systemRed.withAlphaComponent(0.75)
        mutedRed.setFill()
        mutedRed.setStroke()

        let dotSize: CGFloat = 6
        NSBezierPath(ovalIn: NSRect(x: x - dotSize / 2, y: y - dotSize / 2,
                                     width: dotSize, height: dotSize)).fill()
        let line = NSBezierPath()
        line.lineWidth = 1.0
        line.move(to: NSPoint(x: x, y: y))
        line.line(to: NSPoint(x: x + colWidth, y: y))
        line.stroke()
    }

    private func drawEventBlocks(weekStart: Date, colWidth: CGFloat) {
        let timeFmt = DateFormatter()
        timeFmt.timeStyle = .short

        var allLayouts: [(event: DisplayEvent, rect: NSRect)] = []
        for (col, dayEvents) in events {
            allLayouts.append(contentsOf: layoutDayEvents(dayEvents, dayColumn: col, colWidth: colWidth))
        }

        eventRects = allLayouts.map { ($0.event.id, $0.rect) }

        for (event, rect) in allLayouts {
            let isSelected = event.id == selectedEventId
            let bgColor = isSelected ? event.color.pastelSelected : event.color.pastel
            let barColor = bgColor.pastelLighter

            bgColor.setFill()
            NSBezierPath(roundedRect: rect, xRadius: 8, yRadius: 8).fill()

            let barWidth: CGFloat = 4
            let barRect = NSRect(x: rect.minX + 2, y: rect.minY + 2, width: barWidth, height: rect.height - 4)
            barColor.setFill()
            NSBezierPath(roundedRect: barRect, xRadius: 2, yRadius: 2).fill()

            let titleColor = event.color
            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 13, weight: .medium),
                .foregroundColor: titleColor
            ]
            let title = NSAttributedString(string: event.title, attributes: titleAttrs)
            let duration = event.end.timeIntervalSince(event.start)
            let isShortEvent = duration <= 15 * 60
            let textRect = rect.insetBy(dx: isShortEvent ? 8 : 10, dy: isShortEvent ? 1 : 6)
            title.draw(in: textRect)

            let titleSize = title.boundingRect(with: textRect.size, options: [.usesLineFragmentOrigin])
            if textRect.height > titleSize.height + 14 {
                let timeStr = timeFmt.string(from: event.start)
                let timeAttrs: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: 11, weight: .regular),
                    .foregroundColor: NSColor.secondaryLabelColor
                ]
                let timeAS = NSAttributedString(string: timeStr, attributes: timeAttrs)
                let timeRect = NSRect(x: textRect.origin.x, y: textRect.origin.y + titleSize.height + 2,
                                      width: textRect.width, height: 14)
                timeAS.draw(in: timeRect)
            }
        }
        
        if let tempMove = dragController.getTemporaryMoveEvent() {
            let startComps = cal.dateComponents([.hour, .minute], from: tempMove.start)
            let startY = bodyTopOffset + CGFloat(startComps.hour! * 60 + startComps.minute!) / 60.0 * hourHeight
            let height = CGFloat(tempMove.end.timeIntervalSince(tempMove.start)) / 3600.0 * hourHeight
            let x = gutterWidth + CGFloat(tempMove.column) * colWidth + 2
            let rect = NSRect(x: x, y: startY + 1, width: colWidth - 4, height: max(height - 2, hourHeight / 4))

            let bgColor = tempMove.event.color.pastel.withAlphaComponent(0.5)
            let barColor = tempMove.event.color.pastelLighter.withAlphaComponent(0.5)
            bgColor.setFill()
            NSBezierPath(roundedRect: rect, xRadius: 8, yRadius: 8).fill()
            let barWidth: CGFloat = 4
            let barRect = NSRect(x: rect.minX + 2, y: rect.minY + 2, width: barWidth, height: rect.height - 4)
            barColor.setFill()
            NSBezierPath(roundedRect: barRect, xRadius: 2, yRadius: 2).fill()
            let titleAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 13, weight: .medium),
                .foregroundColor: tempMove.event.color.withAlphaComponent(0.7)
            ]
            let title = NSAttributedString(string: tempMove.event.title, attributes: titleAttrs)
            let duration = tempMove.end.timeIntervalSince(tempMove.start)
            let isShortEvent = duration <= 15 * 60
            let textRect = rect.insetBy(dx: isShortEvent ? 8 : 10, dy: isShortEvent ? 1 : 6)
            title.draw(in: textRect)
        } else if let tempEvent = dragController.getTemporaryCreateEvent() ?? pendingCreate.map({ (start: $0.start, end: $0.end, column: $0.column) }) {
            let startComps = cal.dateComponents([.hour, .minute], from: tempEvent.start)
            let startY = bodyTopOffset + CGFloat(startComps.hour! * 60 + startComps.minute!) / 60.0 * hourHeight
            let height = CGFloat(tempEvent.end.timeIntervalSince(tempEvent.start)) / 3600.0 * hourHeight
            let x = gutterWidth + CGFloat(tempEvent.column) * colWidth + 2

            let rect = NSRect(x: x, y: startY + 1, width: colWidth - 4, height: max(height - 2, hourHeight / 4))

            let tempBg = NSColor.systemBlue.pastel
            tempBg.setFill()
            NSBezierPath(roundedRect: rect, xRadius: 8, yRadius: 8).fill()

            let barWidth: CGFloat = 4
            let barRect = NSRect(x: rect.minX + 2, y: rect.minY + 2, width: barWidth, height: rect.height - 4)
            tempBg.pastelLighter.setFill()
            NSBezierPath(roundedRect: barRect, xRadius: 2, yRadius: 2).fill()

            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 13, weight: .medium),
                .foregroundColor: NSColor.systemBlue
            ]
            let timeFormatter = DateFormatter()
            timeFormatter.timeStyle = .short
            let titleStr = "New Event (\(timeFormatter.string(from: tempEvent.start)) - \(timeFormatter.string(from: tempEvent.end)))"
            let title = NSAttributedString(string: titleStr, attributes: attrs)
            title.draw(in: rect.insetBy(dx: 10, dy: 6))
        }
    }

    private func layoutDayEvents(_ dayEvents: [DisplayEvent], dayColumn: Int, colWidth: CGFloat) -> [(event: DisplayEvent, rect: NSRect)] {
        let timed = dayEvents.filter { !$0.isAllDay }.sorted {
            if $0.start == $1.start { return $0.end > $1.end }
            return $0.start < $1.start
        }
        guard !timed.isEmpty else { return [] }

        struct Item {
            let event: DisplayEvent
            let startY: CGFloat
            let endY: CGFloat
            var subCol: Int = 0
        }

        var items: [Item] = timed.map { ev in
            let sc = cal.dateComponents([.hour, .minute], from: ev.start)
            let ec = cal.dateComponents([.hour, .minute], from: ev.end)
            let sy = bodyTopOffset + CGFloat(sc.hour! * 60 + sc.minute!) / 60.0 * hourHeight
            let ey = bodyTopOffset + CGFloat(ec.hour! * 60 + ec.minute!) / 60.0 * hourHeight
            return Item(event: ev, startY: sy, endY: ey)
        }

        var columnEnds: [CGFloat] = []
        for i in items.indices {
            var assigned = -1
            for (c, end) in columnEnds.enumerated() {
                if items[i].startY >= end {
                    assigned = c
                    break
                }
            }
            if assigned == -1 {
                assigned = columnEnds.count
                columnEnds.append(0)
            }
            items[i].subCol = assigned
            columnEnds[assigned] = items[i].endY
        }

        var clusters: [[Int]] = []
        var clusterMaxEnd: CGFloat = -.infinity
        for i in items.indices {
            if clusters.isEmpty || items[i].startY >= clusterMaxEnd {
                clusters.append([i])
                clusterMaxEnd = items[i].endY
            } else {
                clusters[clusters.count - 1].append(i)
                clusterMaxEnd = max(clusterMaxEnd, items[i].endY)
            }
        }

        let baseX = gutterWidth + CGFloat(dayColumn) * colWidth
        var result: [(DisplayEvent, NSRect)] = []

        for cluster in clusters {
            let maxCol = cluster.map({ items[$0].subCol }).max()! + 1
            let slotWidth = (colWidth - 4) / CGFloat(maxCol)

            for idx in cluster {
                let it = items[idx]
                var span = 1
                for nextCol in (it.subCol + 1)..<maxCol {
                    let blocked = cluster.contains { j in
                        items[j].subCol == nextCol && items[j].startY < it.endY && items[j].endY > it.startY
                    }
                    if blocked { break }
                    span += 1
                }
                let x = baseX + 2 + CGFloat(it.subCol) * slotWidth
                let w = slotWidth * CGFloat(span) - 2
                let h = max(it.endY - it.startY - 2, hourHeight / 4)
                result.append((it.event, NSRect(x: x, y: it.startY + 1, width: w, height: h)))
            }
        }
        return result
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
