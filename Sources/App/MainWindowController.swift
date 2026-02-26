import AppKit

class MainWindowController: NSWindowController {
    private let splitVC = NSSplitViewController()
    private let sidebarVC = SidebarViewController()
    private let containerVC = CalendarContainerViewController()
    private let calToolbar = CalendarToolbar()

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1200, height: 800),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered, defer: false
        )
        self.init(window: window)

        window.title = "BCalendar"
        window.center()
        window.setFrameAutosaveName("MainWindow")
        window.minSize = NSSize(width: 800, height: 600)

        let sidebarItem = NSSplitViewItem(sidebarWithViewController: sidebarVC)
        sidebarItem.minimumThickness = 200
        sidebarItem.maximumThickness = 300
        splitVC.addSplitViewItem(sidebarItem)

        let contentItem = NSSplitViewItem(viewController: containerVC)
        contentItem.minimumThickness = 500
        splitVC.addSplitViewItem(contentItem)

        window.contentViewController = splitVC

        calToolbar.onNavigateBack = { [weak self] in self?.navigateBack() }
        calToolbar.onNavigateForward = { [weak self] in self?.navigateForward() }
        calToolbar.onToday = { [weak self] in self?.showToday() }
        calToolbar.onViewModeChanged = { [weak self] mode in self?.switchViewMode(mode) }
        window.toolbar = calToolbar.toolbar

        sidebarVC.onDateSelected = { [weak self] date in
            self?.containerVC.navigateTo(date: date)
            self?.saveState()
            self?.updateToolbar()
        }

        let prefs = Preferences.shared
        switchViewMode(prefs.viewMode)
        containerVC.navigateTo(date: prefs.lastDate)
        updateToolbar()
    }

    private func switchViewMode(_ mode: ViewMode) {
        containerVC.switchTo(mode: mode)
        calToolbar.updateViewMode(mode)
        Preferences.shared.viewMode = mode
        updateToolbar()
    }

    private func navigateBack() {
        containerVC.navigateBackward()
        saveState()
        updateToolbar()
    }

    private func navigateForward() {
        containerVC.navigateForward()
        saveState()
        updateToolbar()
    }

    private func saveState() {
        Preferences.shared.lastDate = containerVC.currentDate
        sidebarVC.miniMonth.select(date: containerVC.currentDate)
    }

    private func updateToolbar() {
        calToolbar.updateTitle(for: containerVC.currentDate, mode: containerVC.currentMode)
    }

    // MARK: - Menu Actions

    @objc func showDayView() { switchViewMode(.day) }
    @objc func showWeekView() { switchViewMode(.week) }
    @objc func showMonthView() { switchViewMode(.month) }

    @objc func showToday() {
        containerVC.navigateTo(date: Date())
        saveState()
        updateToolbar()
    }

    @objc func refresh() {
        NotificationCenter.default.post(name: .syncRequested, object: nil)
    }

    @objc func newEvent() {
        let now = Date()
        let cal = Calendar.current
        let start = cal.date(bySetting: .minute, value: 0, of: now)!
        let end = cal.date(byAdding: .hour, value: 1, to: start)!
        EventEditorWindow.showCreate(startDate: start, endDate: end, allDay: false,
                                      calendarId: nil, relativeTo: window)
    }
}
