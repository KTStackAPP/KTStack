import SwiftUI

// Token động: giá trị light/dark do NSColor dynamic provider tự giải theo appearance của cửa sổ,
// nên cửa sổ ép .aqua vẫn ra light, cửa sổ workspace theo hệ thống.
public enum KTEditorTheme {
    public static let window = Color(kdLight: 0xFFFFFF, dark: 0x1E1E1E)
    public static let content = Color(kdLight: 0xFFFFFF, dark: 0x1E1E1E)
    public static let content2 = Color(kdLight: 0xF7F7FA, dark: 0x252527)
    public static let sidebar = Color(kdLight: 0xFBFBFC, dark: 0x232325)
    public static let separator = Color(kdLight: 0xECECF1, dark: 0x3A3A3C)
    public static let separatorStrong = Color(kdLight: 0xE2E2E8, dark: 0x48484A)

    public static let titlebarTop = Color(kdLight: 0xFBFBFD, dark: 0x2A2A2C)
    public static let titlebarBottom = Color(kdLight: 0xFFFFFF, dark: 0x242426)

    public static let label = Color(kdLight: 0x1D1D1F, dark: 0xF5F5F7)
    public static let label2 = Color(kdLight: 0x6B6B76, dark: 0x98989D)
    public static let label3 = Color(kdLight: 0x9A9AA5, dark: 0x8E8E93)
    public static let faint = Color(kdLight: 0xC0C0C8, dark: 0x5A5A5E)

    public static let accent = Color(kdLight: 0x2F6BFF, dark: 0x0A84FF)
    public static let accentSoft = accent.opacity(0.10)
    public static let onAccent = Color(kdLight: 0xFFFFFF, dark: 0xFFFFFF)

    public static let fieldBg = Color(kdLight: 0xF4F4F7, dark: 0x2C2C2E)
    public static let fieldBorder = Color(kdLight: 0xEAEAEF, dark: 0x3A3A3C)
    public static let btnBg = Color(kdLight: 0xFFFFFF, dark: 0x2C2C2E)
    public static let btnBorder = Color(kdLight: 0xDCDCE3, dark: 0x48484A)
    public static let btnHover = Color(kdLight: 0xF7F7FA, dark: 0x333335)
    public static let pillBg = Color(kdLight: 0xF0F0F3, dark: 0x2C2C2E)
    public static let rowHover = Color(kdLight: 0xFAFAFC, dark: 0x2A2A2C)
    public static let autocompleteBg = Color(kdLight: 0xFFFFFF, dark: 0x2C2C2E)

    public static let switcherIcon = Color(kdLight: 0xF5961E, dark: 0xFF9F0A)

    public enum Status {
        public static let running = Color(kdLight: 0x1FA463, dark: 0x30D158)
        public static let stopped = Color(kdLight: 0x9A9AA5, dark: 0x98989D)
        public static let warning = Color(kdLight: 0xB26A00, dark: 0xFF9F0A)
        public static let error = Color(kdLight: 0xFF453A, dark: 0xFF453A)
        public static let info = Color(kdLight: 0x5E5CE6, dark: 0x5E5CE6)
    }

    public enum Syntax {
        public static let keyword = Color(kdLight: 0x0000FF, dark: 0x569CD6)
        public static let function = Color(kdLight: 0x795E26, dark: 0xDCDCAA)
        public static let string = Color(kdLight: 0xA31515, dark: 0xCE9178)
        public static let number = Color(kdLight: 0x098658, dark: 0xB5CEA8)
        public static let comment = Color(kdLight: 0x008000, dark: 0x6A9955)
        public static let type = Color(kdLight: 0x267F99, dark: 0x4EC9B0)
    }

    public enum Grid {
        public static let headerBg = Color(kdLight: 0xF7F7FA, dark: 0x252527)
        public static let rownumBg = Color(kdLight: 0xFAFAFC, dark: 0x232325)
        public static let cellText = Color(kdLight: 0x1D1D1F, dark: 0xF5F5F7)
        public static let nullText = Color(kdLight: 0x9A9AA5, dark: 0x8E8E93)
        public static let number = Color(kdLight: 0xB26A00, dark: 0xFF9F0A)
        public static let rowHover = Color(kdLight: 0xFAFAFC, dark: 0x2A2A2C)
        public static let border = Color(kdLight: 0xECECF1, dark: 0x3A3A3C)
        public static let editOutline = Color(kdLight: 0x2F6BFF, dark: 0x0A84FF)
        public static let editBg = Color(kdLight: 0x2F6BFF, dark: 0x0A84FF).opacity(0.12)
    }
}
