import AppKit

enum GoogleColorMap {
    /// Uses the hex colors provided by Google Calendar API directly.
    static func color(for hex: String) -> NSColor {
        NSColor(hex: hex) ?? .systemBlue
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

    /// Slightly lighter variant for accent bars (e.g. event left edge).
    var pastelLighter: NSColor {
        blended(withFraction: 0.25, of: .white) ?? self
    }
}
