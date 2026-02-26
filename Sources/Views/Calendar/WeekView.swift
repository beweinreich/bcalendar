import AppKit

class WeekViewController: NSViewController {
    private let scrollView = NSScrollView()
    let timeGrid = TimeGridView()
    private var currentTimeTimer: Timer?

    override func loadView() {
        scrollView.documentView = timeGrid
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        view = scrollView
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        layoutGrid()
        scrollToCurrentTime()
        startCurrentTimeTimer()
    }

    override func viewDidDisappear() {
        super.viewDidDisappear()
        currentTimeTimer?.invalidate()
        currentTimeTimer = nil
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        layoutGrid()
    }

    func update(date: Date, events: [Int: [DisplayEvent]] = [:]) {
        timeGrid.displayDate = date
        timeGrid.numberOfColumns = 7
        timeGrid.events = events
        layoutGrid()
    }

    private func layoutGrid() {
        let width = max(scrollView.contentSize.width, 500)
        timeGrid.frame = NSRect(x: 0, y: 0, width: width, height: timeGrid.totalHeight)
        timeGrid.needsDisplay = true
    }

    private func scrollToCurrentTime() {
        let comps = Calendar.current.dateComponents([.hour], from: Date())
        let hour = max(0, (comps.hour ?? 8) - 1)
        let y = timeGrid.headerHeight + CGFloat(hour) * timeGrid.hourHeight
        scrollView.contentView.scroll(to: NSPoint(x: 0, y: y))
    }

    private func startCurrentTimeTimer() {
        currentTimeTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.timeGrid.needsDisplay = true
        }
    }
}
