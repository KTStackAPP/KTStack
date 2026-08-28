import Foundation

/// Table-level options for CREATE TABLE and ALTER TABLE. `engine`, `charset` and `collation` are
/// raw tokens the renderer allowlists; `comment` is a modeled literal; `autoIncrement` is numeric.
public struct TableOptionDraft: Sendable {
    public var engine: String?
    public var charset: String?
    public var collation: String?
    public var autoIncrement: Int64?
    public var comment: String?

    public init(
        engine: String? = nil,
        charset: String? = nil,
        collation: String? = nil,
        autoIncrement: Int64? = nil,
        comment: String? = nil
    ) {
        self.engine = engine
        self.charset = charset
        self.collation = collation
        self.autoIncrement = autoIncrement
        self.comment = comment
    }

    public var isEmpty: Bool {
        engine == nil && charset == nil && collation == nil && autoIncrement == nil && comment == nil
    }
}
