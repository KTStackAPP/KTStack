import Foundation

public extension Cell {
    var editorText: String? {
        switch self {
        case .blob: nil
        default: displayText
        }
    }
}
