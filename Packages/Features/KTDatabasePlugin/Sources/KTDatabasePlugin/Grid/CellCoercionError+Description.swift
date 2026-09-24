import Foundation

extension CellCoercionError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .notNullable: "This column can't be NULL."
        case let .notInEnum(value): "'\(value)' isn't one of this column's allowed values."
        case let .invalidSetMembers(values): "Not allowed in this set: \(values.joined(separator: ", "))."
        case .defaultNotCoercible: "DEFAULT can't be used as a value here."
        case .binaryNotEditable: "Binary values can't be edited as text."
        }
    }
}
