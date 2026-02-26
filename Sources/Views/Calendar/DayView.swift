import AppKit

class DayViewController: NSViewController {
    private let containerView = SwipeableView()
    private let scrollView = SwipeableScrollView()
    let timeGrid = TimeGridView()
    private var currentTimeTimer: Timer?

    var onSwipeLeft: (() -> Void)? {
        didSet { containerView.onSwipeLeft = onSwipeLeft }
    }
    var onSwipeRight: (() -> Void)? {
        didSet { containerView.onSwipeRight = onSwipeRight }
    }

    override func loadView() {
        containerView.wantsLayer = true
        
        scrollView.documentView = timeGrid
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        
        containerView.addSubview(scrollView)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: containerView.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
        
        view = containerView
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
        timeGrid.numberOfColumns = 1
        timeGrid.events = events
        layoutGrid()
    }

    private func layoutGrid() {
        let width = max(scrollView.contentSize.width, 300)
        timeGrid.frame = NSRect(x: 0, y: 0, width: width, height: timeGrid.totalHeight)
        timeGrid.needsDisplay = true
    }

    private func scrollToCurrentTime() {
        let y = timeGrid.headerHeight + 8 * timeGrid.hourHeight
        scrollView.contentView.scroll(to: NSPoint(x: 0, y: y))
    }

    private func startCurrentTimeTimer() {
        currentTimeTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.timeGrid.needsDisplay = true
        }
    }
}
