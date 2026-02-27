import AppKit

// MARK: - Shared scroll view helpers (used by DayView, MonthGridView)

class SwipeableView: NSView {
    var onSwipeLeft: (() -> Void)?
    var onSwipeRight: (() -> Void)?

    private var accumulatedDeltaX: CGFloat = 0
    private let swipeThreshold: CGFloat = 100
    private var hasTriggeredSwipe = false
    private var lastScrollTime: TimeInterval = 0

    override func scrollWheel(with event: NSEvent) {
        let currentTime = Date().timeIntervalSince1970
        if currentTime - lastScrollTime > 0.5 {
            accumulatedDeltaX = 0
            hasTriggeredSwipe = false
        }
        lastScrollTime = currentTime

        if event.phase.contains(.began) || event.momentumPhase.contains(.began) {
            accumulatedDeltaX = 0
            hasTriggeredSwipe = false
        }

        if abs(event.scrollingDeltaX) > abs(event.scrollingDeltaY) && !hasTriggeredSwipe {
            accumulatedDeltaX += event.scrollingDeltaX

            if accumulatedDeltaX > swipeThreshold {
                onSwipeRight?()
                hasTriggeredSwipe = true
                accumulatedDeltaX = 0
            } else if accumulatedDeltaX < -swipeThreshold {
                onSwipeLeft?()
                hasTriggeredSwipe = true
                accumulatedDeltaX = 0
            }
        } else {
            super.scrollWheel(with: event)
        }

        if event.phase.contains(.ended) || event.phase.contains(.cancelled) || event.momentumPhase.contains(.ended) {
            hasTriggeredSwipe = false
            accumulatedDeltaX = 0
        }
    }
}

class SwipeableScrollView: NSScrollView {
    private var isHorizontalGesture = false

    override func scrollWheel(with event: NSEvent) {
        if event.phase.contains(.began) {
            isHorizontalGesture = abs(event.scrollingDeltaX) > abs(event.scrollingDeltaY)
        }

        if isHorizontalGesture {
            superview?.scrollWheel(with: event)
        } else {
            super.scrollWheel(with: event)
        }

        if event.phase.contains(.ended) || event.phase.contains(.cancelled) {
            isHorizontalGesture = false
        }
    }
}

// MARK: - Week View

class GutterOverlayView: NSView {
    var headerHeight: CGFloat = 54
    var hourHeight: CGFloat = 66
    var verticalScrollOffset: CGFloat = 0 { didSet { needsDisplay = true } }

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.controlBackgroundColor.setFill()
        bounds.fill()

        NSColor.separatorColor.withAlphaComponent(0.25).setStroke()
        NSBezierPath.strokeLine(from: NSPoint(x: 0, y: headerHeight),
                                to: NSPoint(x: bounds.width, y: headerHeight))

        let hourFont = NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .regular)
        let hourColor = NSColor.tertiaryLabelColor

        for hour in 0...23 {
            let y = headerHeight + CGFloat(hour) * hourHeight - verticalScrollOffset
            guard y > headerHeight - 20, y < bounds.height + 20 else { continue }

            let label = hourLabel(hour)
            let attrs: [NSAttributedString.Key: Any] = [.font: hourFont, .foregroundColor: hourColor]
            let s = NSAttributedString(string: label, attributes: attrs)
            let sz = s.size()
            s.draw(at: NSPoint(x: bounds.width - sz.width - 6, y: y - sz.height / 2))
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

/// Scroll view that locks to one direction per gesture.
/// Horizontal scrolling is handled manually (bounds.origin.x) and forwarded via callbacks.
/// Vertical scrolling uses standard NSScrollView behavior.
class DirectionLockedScrollView: NSScrollView {
    var onHorizontalScrollEnd: (() -> Void)?
    var onScrollChanged: (() -> Void)?
    private var isHorizontalGesture = false

    override func scrollWheel(with event: NSEvent) {
        if event.phase.contains(.began) {
            isHorizontalGesture = abs(event.scrollingDeltaX) > abs(event.scrollingDeltaY)
        }

        if isHorizontalGesture {
            if event.momentumPhase == [] {
                var origin = contentView.bounds.origin
                origin.x -= event.scrollingDeltaX
                let maxX = max(0, (documentView?.frame.width ?? 0) - contentView.bounds.width)
                origin.x = max(0, min(maxX, origin.x))
                contentView.setBoundsOrigin(origin)
                reflectScrolledClipView(contentView)
                onScrollChanged?()
            }

            if event.phase.contains(.ended) || event.phase.contains(.cancelled) {
                onHorizontalScrollEnd?()
                isHorizontalGesture = false
            }
        } else {
            super.scrollWheel(with: event)
            if event.phase.contains(.ended) || event.phase.contains(.cancelled) {
                isHorizontalGesture = false
            }
        }
    }
}

class WeekViewController: NSViewController {
    private let containerView = NSView()
    private let headerClipView = NSClipView()
    private let headerView = TimeGridHeaderView()
    private let scrollView = DirectionLockedScrollView()
    let timeGrid = TimeGridView()
    private let gutterOverlay = GutterOverlayView()
    private var currentTimeTimer: Timer?

    let bufferDays = 3
    var totalColumns: Int { 7 + bufferDays * 2 }
    private let gutterWidth: CGFloat = 56

    var onNavigateByDays: ((Int) -> Void)?

    override func loadView() {
        containerView.wantsLayer = true
        containerView.layer?.masksToBounds = true

        headerView.wantsLayer = true
        headerView.usesCustomStartDate = true
        headerClipView.drawsBackground = false
        headerClipView.documentView = headerView

        timeGrid.bodyOnly = true
        timeGrid.usesCustomStartDate = true
        scrollView.documentView = timeGrid
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false

        gutterOverlay.wantsLayer = true
        gutterOverlay.headerHeight = timeGrid.headerHeight
        gutterOverlay.hourHeight = timeGrid.hourHeight

        containerView.addSubview(scrollView)
        containerView.addSubview(gutterOverlay)
        containerView.addSubview(headerClipView)

        view = containerView

        scrollView.onHorizontalScrollEnd = { [weak self] in
            self?.snapToNearestDay()
        }

        scrollView.onScrollChanged = { [weak self] in
            self?.syncHeaderWithScroll()
        }

        scrollView.contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(
            self, selector: #selector(scrollBoundsChanged),
            name: NSView.boundsDidChangeNotification,
            object: scrollView.contentView)
    }

    @objc private func scrollBoundsChanged() {
        gutterOverlay.verticalScrollOffset = scrollView.contentView.bounds.origin.y
        syncHeaderWithScroll()
    }

    private func syncHeaderWithScroll() {
        headerClipView.setBoundsOrigin(NSPoint(x: scrollView.contentView.bounds.origin.x, y: 0))
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

    func rangeStartDate(for date: Date) -> Date {
        let cal = Calendar.current
        return cal.date(byAdding: .day, value: -bufferDays, to: cal.startOfDay(for: date))!
    }

    func update(date: Date, events: [Int: [DisplayEvent]] = [:]) {
        let startDate = rangeStartDate(for: date)

        timeGrid.displayDate = startDate
        timeGrid.numberOfColumns = totalColumns
        timeGrid.events = events

        headerView.displayDate = startDate
        headerView.numberOfColumns = totalColumns

        layoutGrid()
        scrollToCenter()
    }

    private func layoutGrid() {
        let visibleWidth = containerView.bounds.width
        let visibleHeight = containerView.bounds.height
        guard visibleWidth > 0, visibleHeight > 0 else { return }

        let dayWidth = (visibleWidth - gutterWidth) / 7.0
        let totalWidth = gutterWidth + CGFloat(totalColumns) * dayWidth
        let headerH = timeGrid.headerHeight
        let scrollH = visibleHeight - headerH

        headerClipView.frame = NSRect(x: 0, y: scrollH, width: visibleWidth, height: headerH)
        headerView.frame = NSRect(x: 0, y: 0, width: totalWidth, height: headerH)
        scrollView.frame = NSRect(x: 0, y: 0, width: visibleWidth, height: scrollH)
        timeGrid.frame = NSRect(x: 0, y: 0, width: totalWidth, height: timeGrid.totalHeight)
        gutterOverlay.frame = NSRect(x: 0, y: 0, width: gutterWidth, height: visibleHeight)

        timeGrid.needsDisplay = true
        headerView.needsDisplay = true
        gutterOverlay.needsDisplay = true
        syncHeaderWithScroll()
    }

    /// Offset so we show columns 2-8 (one day before currentDate) instead of 3-9.
    /// This keeps events visible when scrolling forward one day.
    private var scrollCenterOffset: CGFloat {
        let dayWidth = (containerView.bounds.width - gutterWidth) / 7.0
        return CGFloat(bufferDays - 1) * dayWidth
    }

    private func scrollToCenter() {
        let dayWidth = (containerView.bounds.width - gutterWidth) / 7.0
        let centerX = scrollCenterOffset
        let currentY = scrollView.contentView.bounds.origin.y
        scrollView.contentView.scroll(to: NSPoint(x: centerX, y: currentY))
        scrollView.reflectScrolledClipView(scrollView.contentView)
        syncHeaderWithScroll()
    }

    private func scrollToCurrentTime() {
        let centerX = scrollCenterOffset
        let y = 8 * timeGrid.hourHeight
        scrollView.contentView.scroll(to: NSPoint(x: centerX, y: y))
        scrollView.reflectScrolledClipView(scrollView.contentView)
        syncHeaderWithScroll()
    }

    private func startCurrentTimeTimer() {
        currentTimeTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.timeGrid.needsDisplay = true
        }
    }

    // MARK: - Snap Logic

    private func snapToNearestDay() {
        let dayWidth = (containerView.bounds.width - gutterWidth) / 7.0
        let currentX = scrollView.contentView.bounds.origin.x
        let centerX = scrollCenterOffset

        let offsetFromCenter = currentX - centerX
        let daysFromCenter = Int(round(offsetFromCenter / dayWidth))
        let clampedDays = max(-bufferDays, min(bufferDays, daysFromCenter))

        if clampedDays != 0 {
            // Animate to target day within current content first, then update.
            // This avoids a jump: updating content first would show the wrong day at the preserved scroll position.
            let targetX = centerX + CGFloat(clampedDays) * dayWidth
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.3
                var newBounds = self.scrollView.contentView.bounds
                newBounds.origin.x = targetX
                self.scrollView.contentView.animator().bounds = newBounds

                var hBounds = self.headerClipView.bounds
                hBounds.origin.x = targetX
                self.headerClipView.animator().bounds = hBounds
            }, completionHandler: { [weak self] in
                self?.onNavigateByDays?(clampedDays)
            })
        } else {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.3
                var newBounds = self.scrollView.contentView.bounds
                newBounds.origin.x = centerX
                self.scrollView.contentView.animator().bounds = newBounds

                var hBounds = self.headerClipView.bounds
                hBounds.origin.x = centerX
                self.headerClipView.animator().bounds = hBounds
            }
        }
    }
}
