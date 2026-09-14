import AppKit

/// Design tokens copied from the prototype's `#quota-mvp` CSS custom properties
/// in `docs/2026-09-11-ai-usage-menu-mvp-prototype.html`.
enum SettingsTheme {
    enum Token {
        case window
        case sidebar
        case popover
        case surface
        case surfaceHover
        case text
        case muted
        case border
        case track
        case green
        case yellow
        case red
        case purple
    }

    /// Mirrors the prototype's `light-dark(...)` pairs.
    static func color(_ token: Token, for appearance: NSAppearance) -> NSColor {
        let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        switch token {
        case .window: return isDark ? hex(0x24262D) : hex(0xF6F6F8)
        case .sidebar: return isDark ? hex(0x1D1F25) : hex(0xEBEBEE)
        case .popover: return isDark ? hex(0x2B2D34) : hex(0xFFFFFF)
        case .surface: return isDark ? hex(0x34363E) : hex(0xF1F1F4)
        case .surfaceHover: return isDark ? hex(0x3E414A) : hex(0xE6E6EA)
        case .text: return isDark ? hex(0xF5F6F7) : hex(0x15161A)
        case .muted: return isDark ? hex(0xAEB2BC) : hex(0x686B73)
        case .border: return isDark ? hex(0xFFFFFF, alpha: 0.12) : hex(0x14141E, alpha: 0.14)
        case .track: return isDark ? hex(0x484B54) : hex(0xD8D9DE)
        case .green: return isDark ? hex(0x4ED889) : hex(0x16844A)
        case .yellow: return isDark ? hex(0xFFC75A) : hex(0xA46200)
        case .red: return isDark ? hex(0xFF6D6D) : hex(0xC43B3B)
        case .purple: return isDark ? hex(0x9D83FF) : hex(0x6546CA)
        }
    }

    /// Dynamic colors follow the effective appearance automatically, so text colors
    /// do not need to be re-applied when the system switches between light and dark.
    static func dynamic(_ token: Token) -> NSColor {
        NSColor(name: nil) { appearance in color(token, for: appearance) }
    }

    static func hex(_ value: UInt32, alpha: CGFloat = 1) -> NSColor {
        NSColor(
            srgbRed: CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255,
            alpha: alpha
        )
    }
}

/// Layout constants copied from the prototype's settings CSS.
/// The prototype uses one shared control height and radius for every control.
enum SettingsMetrics {
    static let windowWidth: CGFloat = 700
    static let minimumContentHeight: CGFloat = 478

    static let sidebarWidth: CGFloat = 185
    static let sidebarPadding = NSEdgeInsets(top: 18, left: 12, bottom: 18, right: 12)
    static let navLabelSpacing: CGFloat = 9
    static let navItemSpacing: CGFloat = 4
    static let navItemIconGap: CGFloat = 9
    static let navItemIconSize: CGFloat = 16

    /// `--qm-settings-main { padding: 34px 38px 28px }`
    static let contentInsets = NSEdgeInsets(top: 34, left: 38, bottom: 28, right: 38)

    static let titleSpacing: CGFloat = 7
    static let subtitleSpacing: CGFloat = 30
    static let groupSpacing: CGFloat = 25
    static let labelSpacing: CGFloat = 9
    static let helpSpacing: CGFloat = 6
    static let footerSpacing: CGFloat = 30
    static let footerGap: CGFloat = 10

    /// `--qm-control-height` / `--qm-control-radius`
    static let controlHeight: CGFloat = 40
    static let controlRadius: CGFloat = 9

    static let fieldPadding: CGFloat = 12
    static let fieldSpacing: CGFloat = 9
    static let portFieldWidth: CGFloat = 145

    static let cardPadding: CGFloat = 13
    static let cardSpacing: CGFloat = 10

    static let chipPadding: CGFloat = 13
    static let chipSpacing: CGFloat = 10
    static let chipContentGap: CGFloat = 7

    static let buttonPadding: CGFloat = 14

    static let vendorGroupSpacing: CGFloat = 15
    static let vendorBlockSpacing: CGFloat = 8
    static let vendorIconSize: CGFloat = 14
    static let vendorSpacing: CGFloat = 7
    static let vendorMinHeight: CGFloat = 22

    static let toggleMinHeight: CGFloat = 48
    static let switchSize = NSSize(width: 40, height: 24)

    static let connectionMinHeight: CGFloat = 38
    static let connectionGap: CGFloat = 8

    static let radioDotSize: CGFloat = 16
}
