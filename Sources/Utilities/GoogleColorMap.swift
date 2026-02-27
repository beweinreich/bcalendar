import AppKit

enum GoogleColorMap {
    static let colors: [String: NSColor] = [
        "#4285F4": NSColor.systemBlue,
        "#EA4335": NSColor.systemRed,
        "#FBBC05": NSColor.systemYellow,
        "#34A853": NSColor.systemGreen,
        "#FF6D01": NSColor.systemOrange,
        "#46BDC6": NSColor.systemTeal,
        "#7986CB": NSColor.systemPurple,
        "#E67C73": NSColor(red: 0.9, green: 0.49, blue: 0.45, alpha: 1),
        "#F4511E": NSColor(red: 0.96, green: 0.32, blue: 0.12, alpha: 1),
        "#33B679": NSColor(red: 0.2, green: 0.71, blue: 0.47, alpha: 1),
        "#039BE5": NSColor(red: 0.01, green: 0.61, blue: 0.9, alpha: 1),
        "#D50000": NSColor(red: 0.83, green: 0, blue: 0, alpha: 1),
    ]

    static func color(for hex: String) -> NSColor {
        colors[hex] ?? NSColor(hex: hex) ?? .systemBlue
    }
}

extension NSColor {
    convenience init?(hex: String) {
        var h = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if h.hasPrefix("#") { h.removeFirst() }
        guard h.count == 6, let val = UInt64(h, radix: 16) else { return nil }
        self.init(red: CGFloat((val >> 16) & 0xFF) / 255,
                  green: CGFloat((val >> 8) & 0xFF) / 255,
                  blue: CGFloat(val & 0xFF) / 255, alpha: 1)
    }

    /// Soft pastel variant — alpha-based so it adapts to light and dark backgrounds.
    var pastel: NSColor {
        withAlphaComponent(0.18)
    }

    /// Slightly stronger pastel for selected states.
    var pastelSelected: NSColor {
        withAlphaComponent(0.30)
    }
}
