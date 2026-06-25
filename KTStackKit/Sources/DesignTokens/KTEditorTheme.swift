import SwiftUI

public enum KTEditorTheme {
    public static let window = Color(hex: 0x1E1E1E)
    public static let content = Color(hex: 0x252527)
    public static let content2 = Color(hex: 0x2C2C2E)
    public static let sidebar = Color(hex: 0x232325)
    public static let separator = Color(hex: 0x38383A)

    public static let titlebarTop = Color(hex: 0x2B2B2D)
    public static let titlebarBottom = Color(hex: 0x252527)

    public static let label = Color.white.opacity(0.85)
    public static let label2 = Color(hex: 0xEBEBF5, opacity: 0.55)
    public static let label3 = Color(hex: 0xEBEBF5, opacity: 0.30)

    public static let accent = Color(hex: 0x0A84FF)
    public static let accentSoft = Color(hex: 0x0A84FF, opacity: 0.12)
    public static let onAccent = Color.white

    public static let fieldBg = Color.white.opacity(0.06)
    public static let btnBg = Color.white.opacity(0.04)
    public static let btnHover = Color.white.opacity(0.09)
    public static let pillBg = Color.white.opacity(0.06)
    public static let rowHover = Color.white.opacity(0.05)
    public static let autocompleteBg = Color(hex: 0x2B2B2E)

    public enum Status {
        public static let running = Color(hex: 0x30D158)
        public static let stopped = Color(hex: 0x98989D)
        public static let warning = Color(hex: 0xFF9F0A)
        public static let error = Color(hex: 0xFF453A)
        public static let info = Color(hex: 0x5E5CE6)
    }

    public enum Syntax {
        public static let keyword = Color(hex: 0xFF7AB2)
        public static let function = Color(hex: 0x82AAFF)
        public static let string = Color(hex: 0x6BD968)
        public static let number = Color(hex: 0xFFB454)
        public static let comment = Color(hex: 0x6C7086)
    }

    public enum Grid {
        public static let headerBg = Color(hex: 0x2A2A2C)
        public static let rownumBg = Color(hex: 0x262628)
        public static let cellText = Color.white.opacity(0.85)
        public static let nullText = Color(hex: 0xEBEBF5, opacity: 0.30)
        public static let number = Color(hex: 0xFFB454)
        public static let rowHover = Color.white.opacity(0.03)
        public static let border = Color(hex: 0x38383A)
        public static let editOutline = Color(hex: 0x0A84FF)
        public static let editBg = Color(hex: 0x0A84FF, opacity: 0.12)
    }
}
