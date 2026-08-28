import Foundation

/// A referential action for a foreign key. Raw values are the exact MySQL/MariaDB keywords.
public enum FKAction: String, Sendable, Hashable, CaseIterable {
    case restrict = "RESTRICT"
    case cascade = "CASCADE"
    case setNull = "SET NULL"
    case noAction = "NO ACTION"
    case setDefault = "SET DEFAULT"
}

public struct IndexDraft: Sendable, Identifiable {
    public let id: UUID
    public var name: String
    public var columns: [String]
    public var isUnique: Bool

    public init(id: UUID = UUID(), name: String, columns: [String], isUnique: Bool = false) {
        self.id = id
        self.name = name
        self.columns = columns
        self.isUnique = isUnique
    }
}

public struct ForeignKeyDraft: Sendable, Identifiable {
    public let id: UUID
    public var name: String
    public var columns: [String]
    public var refTable: String
    public var refColumns: [String]
    public var onDelete: FKAction
    public var onUpdate: FKAction

    public init(
        id: UUID = UUID(),
        name: String,
        columns: [String],
        refTable: String,
        refColumns: [String],
        onDelete: FKAction = .restrict,
        onUpdate: FKAction = .restrict
    ) {
        self.id = id
        self.name = name
        self.columns = columns
        self.refTable = refTable
        self.refColumns = refColumns
        self.onDelete = onDelete
        self.onUpdate = onUpdate
    }
}

/// A CHECK constraint. The expression is raw SQL (previewed); the renderer blocks statement
/// terminators and control characters only.
public struct CheckConstraintDraft: Sendable, Identifiable {
    public let id: UUID
    public var name: String
    public var expression: String

    public init(id: UUID = UUID(), name: String, expression: String) {
        self.id = id
        self.name = name
        self.expression = expression
    }
}

/// One supported schema edit against an existing table. The renderer turns each into a single
/// statement so a partial apply can report exactly which changes ran.
public enum SchemaChange: Sendable {
    case addColumn(ColumnDraft, after: String?)
    case modifyColumn(original: String, ColumnDraft)
    case dropColumn(String)
    case setPrimaryKey([String])
    case dropPrimaryKey
    case addIndex(IndexDraft)
    case dropIndex(String)
    case addForeignKey(ForeignKeyDraft)
    case dropForeignKey(String)
    case addCheck(CheckConstraintDraft)
    case dropCheck(String)
    case setTableOptions(TableOptionDraft)

    public var isDestructive: Bool {
        switch self {
        case .dropColumn, .dropPrimaryKey, .dropIndex, .dropForeignKey, .dropCheck:
            true
        default:
            false
        }
    }
}

/// A rendered DDL statement with a human summary and destructive flag. The preview lists these in
/// execution order; apply runs them one by one and stops at the first error.
public struct DDLStatement: Sendable, Equatable, Identifiable {
    public let sql: String
    public let summary: String
    public let isDestructive: Bool

    public var id: String { sql }

    public init(sql: String, summary: String, isDestructive: Bool = false) {
        self.sql = sql
        self.summary = summary
        self.isDestructive = isDestructive
    }
}
