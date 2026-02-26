import AppKit

class CalendarContainerViewController: NSViewController {
    private(set) var currentMode: ViewMode = .month
    private(set) var currentDate: Date = Date()

    private lazy var monthVC = MonthGridViewController()
    private lazy var weekVC = WeekViewController()
    private lazy var dayVC = DayViewController()

    private let dataSource = EventDataSource()
    private var activeVC: NSViewController?

    override func loadView() {
        view = NSView()
        view.wantsLayer = true
        dataSource.reload()

        setupDragHandlers()

        NotificationCenter.default.addObserver(self, selector: #selector(dataChanged),
                                                name: .eventsChanged, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(dataChanged),
                                                name: .calendarsChanged, object: nil)
    }

    private func setupDragHandlers() {
        let grids = [weekVC.timeGrid, dayVC.timeGrid]
        for grid in grids {
            grid.dragController.delegate = self

            grid.onEventClicked = { [weak self] eventId, screenPoint in
                self?.showEventPopover(eventId: eventId, at: screenPoint, from: grid)
            }
            grid.onEventDoubleClicked = { [weak self] eventId in
                self?.editEvent(eventId: eventId)
            }
        }
    }

    @objc private func dataChanged() {
        dataSource.reload()
        updateActiveView()
    }

    func switchTo(mode: ViewMode) {
        currentMode = mode
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
    }

    func navigateBackward() {
        let cal = Calendar.current
        switch currentMode {
        case .day:   currentDate = cal.date(byAdding: .day, value: -1, to: currentDate)!
        case .week:  currentDate = cal.date(byAdding: .weekOfYear, value: -1, to: currentDate)!
        case .month: currentDate = cal.date(byAdding: .month, value: -1, to: currentDate)!
        }
        updateActiveView()
    }

    func navigateTo(date: Date) {
        currentDate = date
        updateActiveView()
    }

    private func swapChild(to newVC: NSViewController) {
        activeVC?.view.removeFromSuperview()
        activeVC?.removeFromParent()

        addChild(newVC)
        newVC.view.frame = view.bounds
        newVC.view.autoresizingMask = [.width, .height]
        view.addSubview(newVC.view)
        activeVC = newVC
    }

    private func updateActiveView() {
        switch currentMode {
        case .day:
            dayVC.update(date: currentDate, events: dataSource.eventsForDay(date: currentDate))
        case .week:
            weekVC.update(date: currentDate, events: dataSource.eventsForWeek(date: currentDate))
        case .month:
            monthVC.update(date: currentDate, events: dataSource.eventsForMonth(date: currentDate))
        }
    }

    private func showEventPopover(eventId: String, at screenPoint: NSPoint, from sourceView: NSView) {
        guard let event = try? EventStore(db: DatabaseManager.shared.pool).find(eventId) else { return }

        let color = dataSource.calendarColors(for: event.calendarId)
        let popoverVC = EventPopoverController()
        popoverVC.configure(event: event, color: color)
        popoverVC.onEdit = { [weak self] event in
            self?.editEvent(event: event)
        }
        popoverVC.onDelete = { [weak self] event in
            self?.deleteEvent(event)
        }

        let popover = NSPopover()
        popover.contentViewController = popoverVC
        popover.behavior = .transient
        let localPoint = sourceView.convert(screenPoint, from: nil)
        popover.show(relativeTo: NSRect(origin: localPoint, size: .zero), of: sourceView, preferredEdge: .maxY)
    }

    private func editEvent(eventId: String) {
        guard let event = try? EventStore(db: DatabaseManager.shared.pool).find(eventId) else { return }
        editEvent(event: event)
    }

    private func editEvent(event: Event) {
        if event.recurringEventId != nil || event.recurrence != nil {
            EventEditorWindow.confirmRecurringAction(title: "Edit Recurring Event", window: view.window) { scope in
                switch scope {
                case .thisEvent, .thisAndFuture:
                    EventEditorWindow.showEdit(event: event, relativeTo: self.view.window)
                case .allEvents:
                    if let masterId = event.recurringEventId,
                       let master = try? EventStore(db: DatabaseManager.shared.pool).find(masterId) {
                        EventEditorWindow.showEdit(event: master, relativeTo: self.view.window)
                    } else {
                        EventEditorWindow.showEdit(event: event, relativeTo: self.view.window)
                    }
                }
            }
        } else {
            EventEditorWindow.showEdit(event: event, relativeTo: view.window)
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
    func dragDidCreateEvent(start: Date, end: Date, column: Int) {
        EventEditorWindow.showCreate(startDate: start, endDate: end, allDay: false,
                                      calendarId: nil, relativeTo: view.window)
    }

    func dragDidMoveEvent(eventId: String, newStart: Date, newEnd: Date) {
        EventActions.moveEvent(eventId, newStart: newStart, newEnd: newEnd)
    }

    func dragDidResizeEvent(eventId: String, newEnd: Date) {
        guard let event = try? EventStore(db: DatabaseManager.shared.pool).find(eventId) else { return }
        EventActions.moveEvent(eventId, newStart: event.start, newEnd: newEnd)
    }
}
