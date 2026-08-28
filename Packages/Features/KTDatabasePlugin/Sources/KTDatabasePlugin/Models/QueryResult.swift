import Foundation

public enum Cell: Sendable, Hashable {
    case text(String)
    case int(Int64)
    case double(Double)
    case bool(Bool)
    case null
    case blob(Data)

    public var displayText: String? {
        switch self {
        case let .text(s): s
        case let .int(n): String(n)
        case let .double(d): String(d)
        case let .bool(b): b ? "1" : "0"
        case .null: nil
        case let .blob(d): "[\(d.count) bytes]"
        }
    }
}

public struct ColumnMeta: Sendable, Equatable {
    public let name: String
    public let typeName: String?

    public init(name: String, typeName: String? = nil) {
        self.name = name
        self.typeName = typeName
    }
}

public struct QueryResult: Sendable, Equatable {
    public let columns: [ColumnMeta]
    public let rows: [[Cell]]
    public let truncated: Bool
    public let estimatedTotal: Int?

    public init(
        columns: [ColumnMeta],
        rows: [[Cell]],
        truncated: Bool = false,
        estimatedTotal: Int? = nil
    ) {
        self.columns = columns
        self.rows = rows
        self.truncated = truncated
        self.estimatedTotal = estimatedTotal
    }

    public var rowCount: Int {
        rows.count
    }

    public var columnNames: [String] {
        columns.map(\.name)
    }

    public static func == (lhs: QueryResult, rhs: QueryResult) -> Bool {
        lhs.columns == rhs.columns && lhs.rows == rhs.rows
    }
}

public struct ColumnValue: Sendable, Hashable {
    public let column: String
    public let value: Cell
    // Ghi bằng keyword DEFAULT (unbound), không đưa `value` vào binds.
    public let isDefault: Bool

    public init(column: String, value: Cell) {
        self.column = column
        self.value = value
        self.isDefault = false
    }

    public init(defaultFor column: String) {
        self.column = column
        self.value = .null
        self.isDefault = true
    }
}
