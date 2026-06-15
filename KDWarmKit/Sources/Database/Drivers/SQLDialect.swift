import Foundation

/// Per-engine SQL composition. A strategy from the start (not MySQL-only) so PostgreSQL/SQLite add a
/// quote char rather than reshaping the type. Identifiers (table/column names) can't be bound
/// parameters, so `quoteIdent` is the sole defense against identifier injection — it doubles the
/// engine's quote char and rejects characters that doubling can't neutralize.
public struct SQLDialect: Sendable {
    /// The character the engine wraps identifiers in: backtick for MySQL, double-quote for the
    /// SQL-standard engines (PostgreSQL/SQLite).
    public let quote: Character

    public static func forKind(_ kind: DatabaseKind) -> SQLDialect {
        switch kind {
        case .mysql:                       return SQLDialect(quote: "`")
        case .postgres, .sqlite, .mongodb: return SQLDialect(quote: "\"")
        }
    }

    /// Quote an identifier safely. Doubles every embedded quote char so it can't terminate the quoted
    /// identifier, and rejects NUL/newline/empty: NUL can truncate at the C-string boundary inside the
    /// server and a newline has no escape inside a quoted identifier, so neither is ever a legitimate
    /// name — fail closed rather than emit a string that doubling can't make safe.
    public func quoteIdent(_ identifier: String) throws -> String {
        guard !identifier.isEmpty else {
            throw DatabaseError.connection("Empty SQL identifier")
        }
        guard !identifier.contains("\u{0}"), !identifier.contains(where: \.isNewline) else {
            throw DatabaseError.connection("Illegal character in SQL identifier")
        }
        let escaped = identifier.replacingOccurrences(of: String(quote), with: String(repeating: quote, count: 2))
        return "\(quote)\(escaped)\(quote)"
    }

    /// `schema.table`, both parts quoted independently.
    public func qualifiedTable(schema: String, table: String) throws -> String {
        "\(try quoteIdent(schema)).\(try quoteIdent(table))"
    }

    /// Append `LIMIT … OFFSET …` to a SELECT. `limit` is clamped to ≥ 1 (a zero/negative limit is
    /// either malformed or a silently-unbounded scan) and `offset` to ≥ 0. Both are integers, so no
    /// quoting/binding is needed — there's no injection surface.
    public func paginate(_ sql: String, limit: Int, offset: Int) -> String {
        let safeLimit = max(1, limit)
        let safeOffset = max(0, offset)
        return "\(sql) LIMIT \(safeLimit) OFFSET \(safeOffset)"
    }
}
