import Foundation

public struct DatabaseInfo: Sendable, Hashable, Identifiable {
    public let name: String
    public var id: String {
        name
    }

    public init(name: String) {
        self.name = name
    }
}

public struct TableInfo: Sendable, Hashable, Identifiable {
    public let name: String
    public let isView: Bool
    public var id: String {
        name
    }

    public init(name: String, isView: Bool = false) {
        self.name = name
        self.isView = isView
    }
}

public struct ColumnInfo: Sendable, Hashable, Identifiable {
    public let name: String
    public let dataType: String
    public let isNullable: Bool
    public let isPrimaryKey: Bool
    public let defaultValue: String?
    // Thuộc tính bổ sung cho structure editor round-trip; driver không hỗ trợ để mặc định.
    public let isAutoIncrement: Bool
    public let comment: String?
    public let charset: String?
    public let collation: String?
    public let generationExpression: String?
    public let generationStored: Bool
    public let onUpdateCurrentTimestamp: Bool
    public let defaultIsExpression: Bool

    public var id: String {
        name
    }

    public init(
        name: String,
        dataType: String,
        isNullable: Bool,
        isPrimaryKey: Bool,
        defaultValue: String? = nil,
        isAutoIncrement: Bool = false,
        comment: String? = nil,
        charset: String? = nil,
        collation: String? = nil,
        generationExpression: String? = nil,
        generationStored: Bool = false,
        onUpdateCurrentTimestamp: Bool = false,
        defaultIsExpression: Bool = false
    ) {
        self.name = name
        self.dataType = dataType
        self.isNullable = isNullable
        self.isPrimaryKey = isPrimaryKey
        self.defaultValue = defaultValue
        self.isAutoIncrement = isAutoIncrement
        self.comment = comment
        self.charset = charset
        self.collation = collation
        self.generationExpression = generationExpression
        self.generationStored = generationStored
        self.onUpdateCurrentTimestamp = onUpdateCurrentTimestamp
        self.defaultIsExpression = defaultIsExpression
    }
}

public extension [ColumnInfo] {
    var primaryKeyColumns: [ColumnInfo] {
        filter(\.isPrimaryKey)
    }
}

/// One index on a table — grouped from per-column rows so a multi-column index lists every member.
public struct IndexInfo: Sendable, Hashable, Identifiable {
    public let name: String
    public let columns: [String]
    public let isUnique: Bool

    public var id: String {
        name
    }

    public init(name: String, columns: [String], isUnique: Bool) {
        self.name = name
        self.columns = columns
        self.isUnique = isUnique
    }
}

/// A column spec used to compose DDL (CREATE TABLE / ADD COLUMN). Distinct from `ColumnInfo`
/// (which describes an existing column): `type` is a raw SQL type string the dialect sanitizes.
public struct ColumnDefinition: Sendable, Hashable, Identifiable {
    public let name: String
    public let type: String
    public let isNullable: Bool
    public let isPrimaryKey: Bool

    public var id: String {
        name
    }

    public init(name: String, type: String, isNullable: Bool = true, isPrimaryKey: Bool = false) {
        self.name = name
        self.type = type
        self.isNullable = isNullable
        self.isPrimaryKey = isPrimaryKey
    }
}

/// A CHECK constraint introspected from the server. `expression` is the raw CHECK clause as the
/// server stores it; the editor shows it and can drop by name.
public struct CheckConstraintInfo: Sendable, Hashable, Identifiable {
    public let name: String
    public let expression: String

    public var id: String { name }

    public init(name: String, expression: String) {
        self.name = name
        self.expression = expression
    }
}
