import AppKit

protocol DragControllerDelegate: AnyObject {
    func dragDidCreateEvent(start: Date, end: Date, column: Int)
    func dragDidMoveEvent(eventId: String, newStart: Date, newEnd: Date)
    func dragDidResizeEvent(eventId: String, newEnd: Date)
}

class DragController {
    weak var delegate: DragControllerDelegate?
    weak var timeGrid: TimeGridView?

    private(set) var isDragging = false
    private var dragType: DragType = .create
    private(set) var dragStartPoint: NSPoint = .zero
    private var dragEventId: String?
    private var dragStartDate: Date?
    private var dragCurrentDate: Date?
    private var dragOriginalStart: Date?
    private var dragOriginalEnd: Date?

    private enum DragType {
        case create, move, resize
    }

    func mouseDown(at point: NSPoint, in grid: TimeGridView) {
        timeGrid = grid
        dragStartPoint = point

        if let (eventId, hitZone) = hitTestEvent(at: point, in: grid) {
            dragEventId = eventId
            if hitZone == .bottom {
                dragType = .resize
            } else {
                dragType = .move
            }
            if let event = findDisplayEvent(eventId, in: grid) {
                dragOriginalStart = event.start
                dragOriginalEnd = event.end
            }
        } else {
            dragType = .create
            dragStartDate = dateFromPoint(point, in: grid)
            dragCurrentDate = dragStartDate
        }
        isDragging = true
    }

    func mouseDragged(to point: NSPoint, in grid: TimeGridView) {
        guard isDragging else { return }
        
        if dragType == .create {
            dragCurrentDate = dateFromPoint(point, in: grid)
            grid.needsDisplay = true
        }
    }

    func mouseUp(at point: NSPoint, in grid: TimeGridView) {
        guard isDragging else { return }
        isDragging = false

        switch dragType {
        case .create:
            guard let startDate = dragStartDate else { return }
            let endDate = dateFromPoint(point, in: grid) ?? startDate.addingTimeInterval(3600)
            
            // Only create if the drag distance is significant (e.g., more than 5 pixels)
            let dragDistance = abs(point.y - dragStartPoint.y)
            guard dragDistance > 5 else {
                dragEventId = nil
                dragStartDate = nil
                dragCurrentDate = nil
                dragOriginalStart = nil
                dragOriginalEnd = nil
                grid.needsDisplay = true
                return
            }

            let (s, e) = startDate < endDate ? (startDate, endDate) : (endDate, startDate)
            let finalEnd = e.timeIntervalSince(s) < 900 ? s.addingTimeInterval(900) : e
            let col = columnFromPoint(dragStartPoint, in: grid)
            delegate?.dragDidCreateEvent(start: s, end: finalEnd, column: col)

        case .move:
            guard let eventId = dragEventId,
                  let origStart = dragOriginalStart,
                  let origEnd = dragOriginalEnd else { return }
            let dy = point.y - dragStartPoint.y
            let dtSeconds = TimeInterval(dy / grid.hourHeight * 3600)
            let roundedDt = (dtSeconds / 900).rounded() * 900
            let newStart = origStart.addingTimeInterval(roundedDt)
            let newEnd = origEnd.addingTimeInterval(roundedDt)
            delegate?.dragDidMoveEvent(eventId: eventId, newStart: newStart, newEnd: newEnd)

        case .resize:
            guard let eventId = dragEventId else { return }
            if let endDate = dateFromPoint(point, in: grid) {
                delegate?.dragDidResizeEvent(eventId: eventId, newEnd: endDate)
            }
        }

        dragEventId = nil
        dragStartDate = nil
        dragCurrentDate = nil
        dragOriginalStart = nil
        dragOriginalEnd = nil
        grid.needsDisplay = true
    }

    func getTemporaryCreateEvent() -> (start: Date, end: Date, column: Int)? {
        guard isDragging, dragType == .create, let start = dragStartDate, let current = dragCurrentDate, let grid = timeGrid else { return nil }
        
        // Only show the temporary event if the user has dragged a significant distance
        let dragDistance = abs(current.timeIntervalSince(start))
        guard dragDistance > 0 else { return nil }
        
        let s = min(start, current)
        let e = max(start, current)
        let finalEnd = e.timeIntervalSince(s) < 900 ? s.addingTimeInterval(900) : e
        let col = columnFromPoint(dragStartPoint, in: grid)
        return (s, finalEnd, col)
    }

    // MARK: - Helpers

    private func dateFromPoint(_ point: NSPoint, in grid: TimeGridView) -> Date? {
        let gridY = point.y - grid.bodyTopOffset
        guard gridY >= 0 else { return nil }

        let hours = gridY / grid.hourHeight
        let totalMinutes = hours * 60
        let snappedMinutes = Int(round(totalMinutes / 15.0) * 15.0)

        let col = columnFromPoint(point, in: grid)
        let weekStart = grid.weekStartDate()
        let cal = Calendar.current
        let dayStart = cal.date(byAdding: .day, value: col, to: weekStart)!
        return cal.date(byAdding: .minute, value: snappedMinutes, to: dayStart)
    }

    private func columnFromPoint(_ point: NSPoint, in grid: TimeGridView) -> Int {
        let contentWidth = grid.bounds.width - grid.gutterWidth
        let colWidth = contentWidth / CGFloat(grid.numberOfColumns)
        let col = Int((point.x - grid.gutterWidth) / colWidth)
        return max(0, min(col, grid.numberOfColumns - 1))
    }

    enum HitZone { case body, bottom }

    func hitTestEvent(at point: NSPoint, in grid: TimeGridView) -> (String, HitZone)? {
        for (_, dayEvents) in grid.events {
            for event in dayEvents where !event.isAllDay {
                let cal = Calendar.current
                let startComps = cal.dateComponents([.hour, .minute], from: event.start)
                let endComps = cal.dateComponents([.hour, .minute], from: event.end)
                let startY = grid.bodyTopOffset + CGFloat(startComps.hour! * 60 + startComps.minute!) / 60.0 * grid.hourHeight
                let endY = grid.bodyTopOffset + CGFloat(endComps.hour! * 60 + endComps.minute!) / 60.0 * grid.hourHeight

                let weekStart = grid.weekStartDate()
                let dayOffset = cal.dateComponents([.day], from: weekStart, to: event.start).day ?? 0
                let contentWidth = grid.bounds.width - grid.gutterWidth
                let colWidth = contentWidth / CGFloat(grid.numberOfColumns)
                let x = grid.gutterWidth + CGFloat(dayOffset) * colWidth

                let rect = NSRect(x: x, y: startY, width: colWidth, height: max(endY - startY, 15))
                if rect.contains(point) {
                    let isBottom = point.y > rect.maxY - 6
                    return (event.id, isBottom ? .bottom : .body)
                }
            }
        }
        return nil
    }

    private func findDisplayEvent(_ id: String, in grid: TimeGridView) -> DisplayEvent? {
        for (_, events) in grid.events {
            if let e = events.first(where: { $0.id == id }) { return e }
        }
        return nil
    }
}
