import AppKit

class AllDayBannerView: NSView {
    var events: [DisplayEvent] = [] { didSet { needsDisplay = true } }
    var numberOfColumns = 7

    override var isFlipped: Bool { true }
    override var intrinsicContentSize: NSSize {
        let rows = events.isEmpty ? 0 : min(maxRows, (events.count + numberOfColumns - 1) / numberOfColumns)
        return NSSize(width: NSView.noIntrinsicMetric, height: max(CGFloat(rows) * 22 + 4, 0))
    }

    private let maxRows = 3

    override func draw(_ dirtyRect: NSRect) {
        guard !events.isEmpty else { return }

        NSColor.controlBackgroundColor.setFill()
        bounds.fill()

        NSColor.separatorColor.withAlphaComponent(0.2).setStroke()
        NSBezierPath.strokeLine(from: NSPoint(x: 0, y: bounds.height),
                                to: NSPoint(x: bounds.width, y: bounds.height))

        let colWidth = bounds.width / CGFloat(numberOfColumns)

        for (i, event) in events.prefix(numberOfColumns * maxRows).enumerated() {
            let col = i % numberOfColumns
            let row = i / numberOfColumns
            let x = CGFloat(col) * colWidth + 3
            let y = CGFloat(row) * 22 + 2
            let rect = NSRect(x: x, y: y, width: colWidth - 6, height: 18)

            event.color.pastel.setFill()
            NSBezierPath(roundedRect: rect, xRadius: 9, yRadius: 9).fill()

            let titleColor = event.color
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 10, weight: .medium),
                .foregroundColor: titleColor
            ]
            NSAttributedString(string: event.title, attributes: attrs)
                .draw(in: rect.insetBy(dx: 7, dy: 2))
        }
    }
}
