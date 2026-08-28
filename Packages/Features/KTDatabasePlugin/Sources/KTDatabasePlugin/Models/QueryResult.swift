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

extension Cell: Codable {
    private enum Kind: String, Codable { case text, int, double, bool, null, blob }
    private enum CodingKeys: String, CodingKey { case kind, value }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        switch try container.decode(Kind.self, forKey: .kind) {
        case .text: self = .text(try container.decode(String.self, forKey: .value))
        case .int: self = .int(try container.decode(Int64.self, forKey: .value))
        case .double: self = .double(try container.decode(Double.self, forKey: .value))
        case .bool: self = .bool(try container.decode(Bool.self, forKey: .value))
        case .null: self = .null
        case .blob: self = .blob(try container.decode(Data.self, forKey: .value))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .text(value): try container.encode(Kind.text, forKey: .kind); try container.encode(value, forKey: .value)
        case let .int(value): try container.encode(Kind.int, forKey: .kind); try container.encode(value, forKey: .value)
        case let .double(value): try container.encode(Kind.double, forKey: .kind); try container.encode(value, forKey: .value)
        case let .bool(value): try container.encode(Kind.bool, forKey: .kind); try container.encode(value, forKey: .value)
        case .null: try container.encode(Kind.null, forKey: .kind)
        case let .blob(value): try container.encode(Kind.blob, forKey: .kind); try container.encode(value, forKey: .value)
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
