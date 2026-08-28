import Foundation

/// A complete CREATE TABLE modeled from typed parts. The renderer emits one statement from this;
/// the same `ColumnDraft`/`IndexDraft`/`ForeignKeyDraft` types feed both create and alter paths.
public struct TableDefinitionDraft: Sendable {
    public var name: String
    public var columns: [ColumnDraft]
    public var primaryKey: [String]
    public var indexes: [IndexDraft]
    public var foreignKeys: [ForeignKeyDraft]
    public var checks: [CheckConstraintDraft]
    public var options: TableOptionDraft

    public init(
        name: String = "",
        columns: [ColumnDraft] = [],
        primaryKey: [String] = [],
        indexes: [IndexDraft] = [],
        foreignKeys: [ForeignKeyDraft] = [],
        checks: [CheckConstraintDraft] = [],
        options: TableOptionDraft = TableOptionDraft()
    ) {
        self.name = name
        self.columns = columns
        self.primaryKey = primaryKey
        self.indexes = indexes
        self.foreignKeys = foreignKeys
        self.checks = checks
        self.options = options
    }
}
