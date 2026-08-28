import Foundation

/// Modeled default for a column. Values are typed so a default can't smuggle raw DDL:
/// `.text` renders as an escaped string literal, `.number` is validated numeric,
/// `.currentTimestamp` is a keyword. `.expression` is a raw function/expression default
/// (MySQL 8.0.13+ `DEFAULT (expr)`); it stays raw, is sanitized like other expressions and previewed.
public enum ColumnDefault: Sendable, Hashable {
    case none
    case null
    case text(String)
    case number(String)
    case currentTimestamp
    case expression(String)
}

public enum GeneratedKind: String, Sendable, Hashable, CaseIterable {
    case stored = "STORED"
    case virtual = "VIRTUAL"
}

/// A generated-column expression. The expression is raw SQL by nature (it references columns),
/// so it can't be bound; the renderer only blocks statement terminators and control characters
/// and every generated statement is shown before it runs.
public struct GeneratedColumn: Sendable, Hashable {
    public var expression: String
    public var kind: GeneratedKind

    public init(expression: String, kind: GeneratedKind) {
        self.expression = expression
        self.kind = kind
    }
}

/// A column as modeled by the structure editor. `type`, `charset` and `collation` are raw tokens
/// the renderer allowlists; `defaultValue`, `comment` and `generated` are modeled so they can't
/// escape into extra DDL. `originalName` tracks the server-side name for diffing (nil = new column).
public struct ColumnDraft: Sendable, Identifiable {
    public let id: UUID
    public var name: String
    public var type: String
    public var isNullable: Bool
    public var isAutoIncrement: Bool
    public var defaultValue: ColumnDefault
    public var onUpdateCurrentTimestamp: Bool
    public var charset: String?
    public var collation: String?
    public var comment: String?
    public var generated: GeneratedColumn?
    public var originalName: String?

    public init(
        id: UUID = UUID(),
        name: String,
        type: String,
        isNullable: Bool = true,
        isAutoIncrement: Bool = false,
        defaultValue: ColumnDefault = .none,
        onUpdateCurrentTimestamp: Bool = false,
        charset: String? = nil,
        collation: String? = nil,
        comment: String? = nil,
        generated: GeneratedColumn? = nil,
        originalName: String? = nil
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.isNullable = isNullable
        self.isAutoIncrement = isAutoIncrement
        self.defaultValue = defaultValue
        self.onUpdateCurrentTimestamp = onUpdateCurrentTimestamp
        self.charset = charset
        self.collation = collation
        self.comment = comment
        self.generated = generated
        self.originalName = originalName
    }

    // Hai định nghĩa cột giống nhau về DDL (bỏ qua id và originalName) thì modify là no-op.
    func hasSameDefinition(as other: ColumnDraft) -> Bool {
        name == other.name
            && type == other.type
            && isNullable == other.isNullable
            && isAutoIncrement == other.isAutoIncrement
            && defaultValue == other.defaultValue
            && onUpdateCurrentTimestamp == other.onUpdateCurrentTimestamp
            && charset == other.charset
            && collation == other.collation
            && comment == other.comment
            && generated == other.generated
    }
}
