import Foundation

/// A single table cell's typed value. One enum across every relational engine (and reused by the
/// document track) so the grid renders uniformly and the row-CRUD layer can round-trip a value
/// without guessing its type. `.null` is distinct from `.text("")` — a NULL column styles and
/// serializes differently from an empty string. `.blob` carries raw bytes the grid shows as a
/// length/hex summary rather than mangling into a String.
public enum Cell: Sendable, Equatable {
    case text(String)
    case int(Int64)
    case double(Double)
    case bool(Bool)
    case null
    case blob(Data)

    /// Display string for a grid cell. NULL is surfaced by the view as a styled placeholder, so the
    /// model returns nil here rather than the literal "NULL" (which would be indistinguishable from a
    /// text value of "NULL").
    public var displayText: String? {
        switch self {
        case .text(let s):   return s
        case .int(let n):    return String(n)
        case .double(let d): return String(d)
        case .bool(let b):   return b ? "1" : "0"
        case .null:          return nil
        case .blob(let d):   return "[\(d.count) bytes]"
        }
    }
}

/// Metadata for one result column. `name` is the (possibly aliased) label the engine returned;
/// `typeName` is the engine's declared type when known (drives later type-aware editing), nil for
/// computed/expression columns the engine doesn't type.
public struct ColumnMeta: Sendable, Equatable {
    public let name: String
    public let typeName: String?

    public init(name: String, typeName: String? = nil) {
        self.name = name
        self.typeName = typeName
    }
}

/// A query result reduced to what the grid + row editor need: ordered column metadata and rows of
/// typed cells, positional so duplicate column names from a join still map one-to-one. `Sendable`
/// so a driver can resolve it off the event loop and hand it to the `@MainActor` UI without copying
/// through an untyped bag. Columns are carried independently of rows, so a zero-row result still
/// reports its headers.
public struct QueryResult: Sendable, Equatable {
    public let columns: [ColumnMeta]
    public let rows: [[Cell]]

    public init(columns: [ColumnMeta], rows: [[Cell]]) {
        self.columns = columns
        self.rows = rows
    }

    public var rowCount: Int { rows.count }
    public var columnNames: [String] { columns.map(\.name) }
}
