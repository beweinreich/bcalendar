import AppKit

private class ToolbarBarView: NSView {
    override var wantsUpdateLayer: Bool { true }
    override func updateLayer() {
        let isDark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        layer?.backgroundColor = (isDark ? NSColor.windowBackgroundColor : NSColor.controlBackgroundColor).cgColor
    }
}

class CalendarContainerViewController: NSViewController {
    private(set) var currentMode: ViewMode = .month
    private(set) var currentDate: Date = Date()

    private lazy var monthVC = MonthGridViewController()
    private lazy var weekVC = WeekViewController()
    private lazy var dayVC = DayViewController()

    private let dataSource = EventDataSource()
    private var activeVC: NSViewController?
    private var contentContainer: NSView!
    private var toolbarBar: NSView!
    private var toolbarHeightConstraint: NSLayoutConstraint!

    var toolbarView: NSView? {
        didSet { installToolbarIfNeeded() }
    }

    override func loadView() {
        view = NSView()
        view.wantsLayer = true

        toolbarBar = ToolbarBarView()
        toolbarBar.wantsLayer = true
        toolbarBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(toolbarBar)

        contentContainer = NSView()
        contentContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(contentContainer)

        toolbarHeightConstraint = toolbarBar.heightAnchor.constraint(equalToConstant: 0)
        NSLayoutConstraint.activate([
            toolbarBar.topAnchor.constraint(equalTo: view.topAnchor),
            toolbarBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            toolbarBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            toolbarHeightConstraint,
            contentContainer.topAnchor.constraint(equalTo: toolbarBar.bottomAnchor),
            contentContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            contentContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            contentContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        installToolbarIfNeeded()

        dataSource.reload()
        setupDragHandlers()
        NotificationCenter.default.addObserver(self, selector: #selector(dataChanged),
                                                name: .eventsChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(dataChanged),
                                                name: .calendarsChanged, object: nil)
    }

    private func installToolbarIfNeeded() {
        guard let bar = toolbarBar, let toolView = toolbarView else { return }
        guard toolView.superview != bar else { return }
        toolView.removeFromSuperview()
        bar.addSubview(toolView)
        toolView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            toolView.topAnchor.constraint(equalTo: bar.topAnchor),
            toolView.leadingAnchor.constraint(equalTo: bar.leadingAnchor),
            toolView.trailingAnchor.constraint(equalTo: bar.trailingAnchor),
            toolView.bottomAnchor.constraint(equalTo: bar.bottomAnchor),
        ])
        toolbarHeightConstraint.constant = 56
    }

    private func setupDragHandlers() {
        let grids = [weekVC.timeGrid, dayVC.timeGrid]
        for grid in grids {
            grid.dragController.delegate = self
            grid.onEventDoubleClicked = { [weak self] eventId in
                self?.editEvent(eventId: eventId)
            }
            grid.onEventDeleteRequested = { [weak self] eventId in
                self?.confirmAndDeleteEvent(eventId: eventId)
            }
        }
        weekVC.onNavigateByDays = { [weak self] days in
            guard let self = self else { return }
            self.currentDate = Calendar.current.date(byAdding: .day, value: days, to: self.currentDate)!
            self.updateActiveView()
            self.onNavigate?()
        }
        dayVC.onSwipeLeft = { [weak self] in self?.navigateForward() }
        dayVC.onSwipeRight = { [weak self] in self?.navigateBackward() }
        monthVC.onSwipeLeft = { [weak self] in self?.navigateForward() }
        monthVC.onSwipeRight = { [weak self] in self?.navigateBackward() }
    }

    var onNavigate: (() -> Void)?

    private var activeTimeGrid: TimeGridView? {
        switch currentMode {
        case .day: return dayVC.timeGrid
        case .week: return weekVC.timeGrid
        case .month: return nil
        }
    }

    @objc private func dataChanged() {
        dayVC.timeGrid.selectedEventId = nil
        weekVC.timeGrid.selectedEventId = nil
        dataSource.reload()
        updateActiveView()
    }

    func switchTo(mode: ViewMode) {
        currentMode = mode
        if mode == .week {
            currentDate = Calendar.current.dateInterval(of: .weekOfYear, for: currentDate)!.start
        }
        let newVC: NSViewController
        switch mode {
        case .day:   newVC = dayVC
        case .week:  newVC = weekVC
        case .month: newVC = monthVC
        }
        swapChild(to: newVC)
        updateActiveView()
    }

    func navigateForward() {
        let cal = Calendar.current
        switch currentMode {
        case .day:   currentDate = cal.date(byAdding: .day, value: 1, to: currentDate)!
        case .week:  currentDate = cal.date(byAdding: .weekOfYear, value: 1, to: currentDate)!
        case .month: currentDate = cal.date(byAdding: .month, value: 1, to: currentDate)!
        }
        updateActiveView()
        onNavigate?()
    }

    func navigateBackward() {
        let cal = Calendar.current
        switch currentMode {
        case .day:   currentDate = cal.date(byAdding: .day, value: -1, to: currentDate)!
        case .week:  currentDate = cal.date(byAdding: .weekOfYear, value: -1, to: currentDate)!
        case .month: currentDate = cal.date(byAdding: .month, value: -1, to: currentDate)!
        }
        updateActiveView()
        onNavigate?()
    }

    func navigateTo(date: Date) {
        currentDate = date
        updateActiveView()
        onNavigate?()
    }

    private func swapChild(to newVC: NSViewController) {
        activeVC?.view.removeFromSuperview()
        activeVC?.removeFromParent()

        addChild(newVC)
        newVC.view.frame = contentContainer.bounds
        newVC.view.autoresizingMask = [.width, .height]
        contentContainer.addSubview(newVC.view)
        activeVC = newVC
    }

    private func updateActiveView() {
        switch currentMode {
        case .day:
            dayVC.update(date: currentDate, events: dataSource.eventsForDay(date: currentDate))
        case .week:
            let rangeStart = weekVC.rangeStartDate(for: currentDate)
            weekVC.update(date: currentDate, events: dataSource.eventsForRange(startDate: rangeStart, days: weekVC.totalColumns))
        case .month:
            monthVC.update(date: currentDate, events: dataSource.eventsForMonth(date: currentDate))
        }
    }

    private func editEvent(eventId: String) {
        guard let event = try? EventStore(db: DatabaseManager.shared.pool).find(eventId),
              !event.deletedFlag else { return }
        editEvent(event: event)
    }

    private func editEvent(event: Event) {
        guard !event.deletedFlag else { return }
        guard let anchorView = activeTimeGrid,
              let anchorRect = activeTimeGrid?.rectForEvent(id: event.id) else { return }

        if event.recurringEventId != nil || event.recurrence != nil {
            EventEditorWindow.confirmRecurringAction(title: "Edit Recurring Event", window: view.window) { [weak self] scope in
                guard let self else { return }
                let eventToEdit: Event
                switch scope {
                case .thisEvent, .thisAndFuture:
                    eventToEdit = event
                case .allEvents:
                    if let masterId = event.recurringEventId,
                       let master = try? EventStore(db: DatabaseManager.shared.pool).find(masterId) {
                        eventToEdit = master
                    } else {
                        eventToEdit = event
                    }
                }
                let rect = self.activeTimeGrid?.rectForEvent(id: eventToEdit.id) ?? anchorRect
                EventEditorPopover.showEdit(event: eventToEdit, anchorRect: rect, in: anchorView) { }
            }
        } else {
            EventEditorPopover.showEdit(event: event, anchorRect: anchorRect, in: anchorView) { }
        }
    }

    private func confirmAndDeleteEvent(eventId: String) {
        guard let event = try? EventStore(db: DatabaseManager.shared.pool).find(eventId) else { return }
        
        let alert = NSAlert()
        alert.messageText = "Delete Event"
        alert.informativeText = "Are you sure you want to delete this event?"
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning
        
        if let window = view.window {
            alert.beginSheetModal(for: window) { [weak self] response in
                if response == .alertFirstButtonReturn {
                    self?.deleteEvent(event)
                }
            }
        } else {
            if alert.runModal() == .alertFirstButtonReturn {
                deleteEvent(event)
            }
        }
    }

    private func deleteEvent(_ event: Event) {
        if event.recurringEventId != nil || event.recurrence != nil {
            EventEditorWindow.confirmRecurringAction(title: "Delete Recurring Event", window: view.window) { scope in
                EventActions.deleteRecurring(event, scope: scope)
            }
        } else {
            EventActions.deleteEvent(event)
        }
    }
}

extension CalendarContainerViewController: DragControllerDelegate {
    func dragDidCreateEvent(start: Date, end: Date, column: Int, anchorRect: NSRect, anchorView: NSView) {
        guard let grid = anchorView as? TimeGridView else { return }
        grid.pendingCreate = (start, end, column)
        EventEditorPopover.showCreate(startDate: start, endDate: end, allDay: false,
                                      calendarId: nil as String?, anchorRect: anchorRect, in: anchorView) {
            grid.pendingCreate = nil
        }
    }

    func dragDidMoveEvent(eventId: String, newStart: Date, newEnd: Date) {
        EventActions.moveEvent(eventId, newStart: newStart, newEnd: newEnd)
    }

    func dragDidResizeEvent(eventId: String, newEnd: Date) {
        guard let event = try? EventStore(db: DatabaseManager.shared.pool).find(eventId) else { return }
        EventActions.moveEvent(eventId, newStart: event.start, newEnd: newEnd)
    }
}
