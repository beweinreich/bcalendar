import AppKit

class MiniMonthView: NSView {
    var onDateSelected: ((Date) -> Void)?

    private var displayMonth = Date()
    private var selectedDate = Date()
    private let cal = Calendar.current
    private let dayLetters = ["S", "M", "T", "W", "T", "F", "S"]

    private let headerH: CGFloat = 24
    private let dayHeaderH: CGFloat = 16

    func select(date: Date) {
        selectedDate = date
        displayMonth = date
        needsDisplay = true
    }

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        let w = bounds.width
        let (firstOfMonth, daysInMonth, startWeekday) = cal.monthGrid(for: displayMonth)
        let rows = ceil(Double(startWeekday - 1 + daysInMonth) / 7.0)
        let cellW = w / 7
        let cellH = (bounds.height - headerH - dayHeaderH) / CGFloat(rows)

        let monthStr = displayMonth.formatted(as: "MMMM yyyy")
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: .semibold),
            .foregroundColor: NSColor.labelColor
        ]
        let attrStr = NSAttributedString(string: monthStr, attributes: attrs)
        let strSize = attrStr.size()
        attrStr.draw(at: NSPoint(x: w / 2 - strSize.width / 2, y: (headerH - strSize.height) / 2))

        let arrowAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 14, weight: .medium),
            .foregroundColor: NSColor.controlAccentColor
        ]
        NSAttributedString(string: "‹", attributes: arrowAttrs).draw(at: NSPoint(x: 6, y: 3))
        NSAttributedString(string: "›", attributes: arrowAttrs).draw(at: NSPoint(x: w - 14, y: 3))

        let dayAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 9, weight: .medium),
            .foregroundColor: NSColor.tertiaryLabelColor,
            .kern: 0.3
        ]
        for (i, letter) in dayLetters.enumerated() {
            let s = NSAttributedString(string: letter, attributes: dayAttrs)
            let sz = s.size()
            s.draw(at: NSPoint(x: CGFloat(i) * cellW + cellW / 2 - sz.width / 2, y: headerH))
        }

        for day in 1...daysInMonth {
            let offset = startWeekday - 1 + day - 1
            let col = offset % 7
            let row = offset / 7
            let x = CGFloat(col) * cellW
            let y = headerH + dayHeaderH + CGFloat(row) * cellH

            let dayDate = cal.date(byAdding: .day, value: day - 1, to: firstOfMonth)!
            let isToday = cal.isToday(dayDate)
            let isSelected = cal.isSameDay(dayDate, selectedDate) && !isToday

            let numAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 10, weight: isToday ? .bold : .regular),
                .foregroundColor: isToday ? NSColor.white : (isSelected ? NSColor.controlAccentColor : NSColor.labelColor)
            ]
            let s = NSAttributedString(string: "\(day)", attributes: numAttrs)
            let sz = s.size()
            let cx = x + cellW / 2
            let cy = y + cellH / 2

            if isToday {
                let r: CGFloat = 9
                NSColor.systemRed.setFill()
                NSBezierPath(ovalIn: NSRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)).fill()
            } else if isSelected {
                let r: CGFloat = 9
                NSColor.controlAccentColor.withAlphaComponent(0.12).setFill()
                NSBezierPath(ovalIn: NSRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2)).fill()
            }

            s.draw(at: NSPoint(x: cx - sz.width / 2, y: cy - sz.height / 2))
        }
    }

    override func mouseDown(with event: NSEvent) {
        let pt = convert(event.locationInWindow, from: nil)

        if pt.y < headerH {
            if pt.x < 30 {
                displayMonth = cal.date(byAdding: .month, value: -1, to: displayMonth)!
                needsDisplay = true
                return
            } else if pt.x > bounds.width - 30 {
                displayMonth = cal.date(byAdding: .month, value: 1, to: displayMonth)!
                needsDisplay = true
                return
            }
        }

        let (firstOfMonth, daysInMonth, startWeekday) = cal.monthGrid(for: displayMonth)
        let rows = ceil(Double(startWeekday - 1 + daysInMonth) / 7.0)
        let cellW = bounds.width / 7
        let cellH = (bounds.height - headerH - dayHeaderH) / CGFloat(rows)

        let gridY = pt.y - headerH - dayHeaderH
        guard gridY >= 0 else { return }
        let col = Int(pt.x / cellW)
        let row = Int(gridY / cellH)
        let dayIndex = row * 7 + col - (startWeekday - 1) + 1

        if dayIndex >= 1, dayIndex <= daysInMonth {
            let date = cal.date(byAdding: .day, value: dayIndex - 1, to: firstOfMonth)!
            selectedDate = date
            needsDisplay = true
            onDateSelected?(date)
        }
    }
}
