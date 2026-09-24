import Foundation

public enum GridRowRef: Equatable {
    case draft
    case row(table: String, values: [String: Cell])
}
