import AppKit

final class SettingsWindowController: NSWindowController {
    static var shared: SettingsWindowController?

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 500),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered, defer: false
        )
        self.init(window: window)

        window.title = "Accounts"
        window.minSize = NSSize(width: 550, height: 400)
        window.center()

        let contentVC = SettingsViewController()
        window.contentViewController = contentVC
    }

    static func show() {
        if shared == nil {
            shared = SettingsWindowController()
        }
        shared?.showWindow(nil)
        shared?.window?.makeKeyAndOrderFront(nil)
    }
}
