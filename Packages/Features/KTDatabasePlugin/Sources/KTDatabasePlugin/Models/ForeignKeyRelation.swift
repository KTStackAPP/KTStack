import Foundation

public struct ForeignKeyRelation: Sendable, Hashable, Identifiable {
    public let fromTable: String
    public let fromColumn: String
    public let toTable: String
    public let toColumn: String
    public let constraintName: String?
    // Round-trip từ REFERENTIAL_CONSTRAINTS; nil khi server không cấp hoặc engine không introspect.
    public let onDelete: FKAction?
    public let onUpdate: FKAction?

    public init(
        fromTable: String,
        fromColumn: String,
        toTable: String,
        toColumn: String,
        constraintName: String? = nil,
        onDelete: FKAction? = nil,
        onUpdate: FKAction? = nil
    ) {
        self.fromTable = fromTable
        self.fromColumn = fromColumn
        self.toTable = toTable
        self.toColumn = toColumn
        self.constraintName = constraintName
        self.onDelete = onDelete
        self.onUpdate = onUpdate
    }

    public var id: String {
        "\(constraintName ?? "")|\(fromTable).\(fromColumn)->\(toTable).\(toColumn)"
    }
}
