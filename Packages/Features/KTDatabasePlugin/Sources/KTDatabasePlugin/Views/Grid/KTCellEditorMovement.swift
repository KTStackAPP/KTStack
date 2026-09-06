import Foundation

public enum KTCellEditorMovement: Sendable, Hashable, Equatable {
    case tab
    case backtab
    case up
    case down
}

public struct KTCellEditorArrowExit: Sendable {
    public static func canExitUp(text: String, selectedRange: NSRange) -> Bool {
        guard !text.isEmpty else { return true }
        let location = min(max(0, selectedRange.location), text.count)
        let index = text.index(text.startIndex, offsetBy: location)
        let prefix = text[..<index]
        return !prefix.contains("\n")
    }

    public static func canExitDown(text: String, selectedRange: NSRange) -> Bool {
        guard !text.isEmpty else { return true }
        let location = min(max(0, selectedRange.location), text.count)
        let index = text.index(text.startIndex, offsetBy: location)
        let suffix = text[index...]
        return !suffix.contains("\n")
    }
}
