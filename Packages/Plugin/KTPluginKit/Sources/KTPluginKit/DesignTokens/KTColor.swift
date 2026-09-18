import AppKit
import SwiftUI

public extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

public enum KTColor {
    public static let accent = Color(nsColor: .controlAccentColor)
    public static let accentTop = Color(nsColor: .controlAccentColor)
    public static let accentSoft = Color(nsColor: .controlAccentColor).opacity(0.12)
    public static let accentBand = Color(nsColor: .controlAccentColor).opacity(0.06)
    public static let accentGradient = LinearGradient(
        colors: [Color(nsColor: .controlAccentColor), Color(nsColor: .controlAccentColor).opacity(0.85)],
        startPoint: .top, endPoint: .bottom
    )

    public static let ink = Color(nsColor: .labelColor)
    public static let ink2 = Color(nsColor: .secondaryLabelColor)
    public static let ink3 = Color(nsColor: .tertiaryLabelColor)
    public static let muted = Color(nsColor: .quaternaryLabelColor)
    public static let faint = Color(nsColor: .separatorColor)

    public static let contentBg = Color(nsColor: .windowBackgroundColor)
    public static let sidebarBg = Color(nsColor: .controlBackgroundColor)
    public static let rowHover = Color(nsColor: .selectedContentBackgroundColor).opacity(0.08)

    public static let sep = Color(nsColor: .separatorColor)
    public static let sepFaint = Color(nsColor: .separatorColor).opacity(0.60)
    public static let hairline = Color(nsColor: .separatorColor).opacity(0.30)
    public static let sidebarBackground = Color(nsColor: .controlBackgroundColor)

    public static let fieldBg = Color(nsColor: .controlBackgroundColor)
    public static let fieldBorder = Color(nsColor: .separatorColor)
    public static let fieldBorderStrong = Color(nsColor: .separatorColor)

    public static let pillBg = Color(nsColor: .controlBackgroundColor)
    public static let segmentBg = Color(nsColor: .controlBackgroundColor)
    public static let btnBorder = Color(nsColor: .separatorColor)
    public static let btnHover = Color(nsColor: .selectedControlColor)
    public static let menuHover = Color(nsColor: .selectedContentBackgroundColor).opacity(0.10)

    public static let runDot = Color(nsColor: .systemGreen)
    public static let stopDot = Color(nsColor: .secondaryLabelColor)
    public static let runText = Color(nsColor: .labelColor)
    public static let stopText = Color(nsColor: .secondaryLabelColor)
    public static let online = Color(nsColor: .systemGreen)
    public static let onlineBg = Color(nsColor: .systemGreen).opacity(0.12)

    public static let danger = Color(nsColor: .systemRed)
    public static let dangerBg = Color(nsColor: .systemRed).opacity(0.12)
    public static let dangerBorder = Color(nsColor: .systemRed).opacity(0.30)

    public static let editorBg = Color(nsColor: .textBackgroundColor)
    public static let modalScrim = Color(nsColor: .shadowColor).opacity(0.32)
}

public struct KTTint: Sendable, Hashable {
    public let fg: Color
    public let bg: Color
    public init(fg: Color, bg: Color) {
        self.fg = fg; self.bg = bg
    }
}

public enum KTIconTint {
    public static let code = KTTint(fg: Color(hex: 0x2F6BFF), bg: Color(hex: 0xEAF1FF))
    public static let cube = KTTint(fg: Color(hex: 0x8B5CF6), bg: Color(hex: 0xF1ECFF))
    public static let db = KTTint(fg: Color(hex: 0xF5961E), bg: Color(hex: 0xFFF1E0))
    public static let globe = KTTint(fg: Color(hex: 0x1FA463), bg: Color(hex: 0xE7F8EE))
    public static let mail = KTTint(fg: Color(hex: 0xE0467C), bg: Color(hex: 0xFFEDF3))
    public static let neutral = KTTint(fg: Color(hex: 0x86868F), bg: Color(hex: 0xEFEFF3))
    public static let wordpress = KTTint(fg: Color(hex: 0x1E6A8D), bg: Color(hex: 0xE3F1F8))
    public static let laravel = KTTint(fg: Color(hex: 0xD8412F), bg: Color(hex: 0xFDE9E6))
    public static let php = KTTint(fg: Color(hex: 0x6C72B8), bg: Color(hex: 0xECEDF8))
}

public enum KTEngineTint {
    public static func of(_ engine: String) -> KTTint {
        switch engine.lowercased() {
        case "postgresql", "postgres", "pg":
            KTTint(fg: Color(hex: 0x2F6BFF), bg: Color(hex: 0xEAF1FF))
        case "mongodb", "mongo":
            KTTint(fg: Color(hex: 0x13AA52), bg: Color(hex: 0xE5F7EC))
        case "sqlite":
            KTTint(fg: Color(hex: 0x5C6B7A), bg: Color(hex: 0xEEF0F4))
        default:
            KTTint(fg: Color(hex: 0x1FA463), bg: Color(hex: 0xE7F8EE))
        }
    }
}
