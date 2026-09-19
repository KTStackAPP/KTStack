import AppKit
import SwiftUI

public enum KTEditorTheme {
    public static let window = Color(nsColor: .windowBackgroundColor)
    public static let content = Color(nsColor: .windowBackgroundColor)
    public static let content2 = Color(nsColor: .controlBackgroundColor)
    public static let sidebar = Color(nsColor: .controlBackgroundColor)
    public static let separator = Color(nsColor: .separatorColor)
    public static let separatorStrong = Color(nsColor: .separatorColor)

    public static let titlebarTop = Color(nsColor: .windowBackgroundColor)
    public static let titlebarBottom = Color(nsColor: .windowBackgroundColor)

    public static let label = Color(nsColor: .labelColor)
    public static let label2 = Color(nsColor: .secondaryLabelColor)
    public static let label3 = Color(nsColor: .tertiaryLabelColor)
    public static let faint = Color(nsColor: .quaternaryLabelColor)

    public static let accent = Color(nsColor: .controlAccentColor)
    public static let accentSoft = Color(nsColor: .controlAccentColor).opacity(0.12)
    public static let onAccent = Color.white

    public static let fieldBg = Color(nsColor: .controlBackgroundColor)
    public static let fieldBorder = Color(nsColor: .separatorColor)
    public static let btnBg = Color(nsColor: .controlColor)
    public static let btnBorder = Color(nsColor: .separatorColor)
    public static let btnHover = Color(nsColor: .selectedControlColor)
    public static let pillBg = Color(nsColor: .controlBackgroundColor)
    public static let rowHover = Color(nsColor: .selectedContentBackgroundColor).opacity(0.08)
    public static let autocompleteBg = Color(nsColor: .controlBackgroundColor)

    public static let switcherIcon = Color(nsColor: .systemOrange)

    public enum Status {
        public static let running = Color(nsColor: .systemGreen)
        public static let stopped = Color(nsColor: .secondaryLabelColor)
        public static let warning = Color(nsColor: .systemOrange)
        public static let error = Color(nsColor: .systemRed)
        public static let info = Color(nsColor: .systemBlue)
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
        public static let headerBg = Color(nsColor: .controlBackgroundColor)
        public static let rownumBg = Color(nsColor: .controlBackgroundColor)
        public static let cellText = Color(nsColor: .labelColor)
        public static let nullText = Color(nsColor: .tertiaryLabelColor)
        public static let number = Color(nsColor: .systemOrange)
        public static let rowHover = Color(nsColor: .selectedContentBackgroundColor).opacity(0.08)
        public static let border = Color(nsColor: .separatorColor)
        public static let editOutline = Color(nsColor: .controlAccentColor)
        public static let editBg = Color(nsColor: .controlAccentColor).opacity(0.12)
    }
}
