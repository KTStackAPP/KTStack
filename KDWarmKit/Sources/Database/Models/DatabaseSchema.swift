import Foundation

/// A schema (catalog) on a server — MySQL "database", PostgreSQL "schema". Names only; tables are
/// fetched lazily so opening a server with hundreds of schemas doesn't eagerly introspect each.
public struct DatabaseInfo: Sendable, Hashable, Identifiable {
    public let name: String
    public var id: String { name }

    public init(name: String) { self.name = name }
}

/// A table (or view) within a schema. `isView` lets the UI badge views and skip row-edit affordances
/// the relational CRUD phase only grants to base tables.
public struct TableInfo: Sendable, Hashable, Identifiable {
    public let name: String
    public let isView: Bool
    public var id: String { name }

    public init(name: String, isView: Bool = false) {
        self.name = name
        self.isView = isView
    }
}

/// One column's introspected metadata. `isPrimaryKey` is the per-column flag; a table's full primary
/// key is the ordered set of columns where this is true (composite keys are common — the row-edit
/// phase keys UPDATEs on every PK column, not a single `id`). `dataType` is the engine's own type
/// name (e.g. `varchar(255)`, `bigint unsigned`) shown verbatim in the structure view.
public struct ColumnInfo: Sendable, Hashable, Identifiable {
    public let name: String
    public let dataType: String
    public let isNullable: Bool
    public let isPrimaryKey: Bool
    public let defaultValue: String?

    public var id: String { name }

    public init(name: String, dataType: String, isNullable: Bool,
                isPrimaryKey: Bool, defaultValue: String? = nil) {
        self.name = name
        self.dataType = dataType
        self.isNullable = isNullable
        self.isPrimaryKey = isPrimaryKey
        self.defaultValue = defaultValue
    }
}

public extension Array where Element == ColumnInfo {
    /// The table's primary-key columns in declaration order — the key set the row-edit phase builds
    /// UPDATE/DELETE predicates from. Empty when the table has no PK (edits then fall back to a
    /// full-row match, decided in the CRUD phase).
    var primaryKeyColumns: [ColumnInfo] { filter(\.isPrimaryKey) }
}
