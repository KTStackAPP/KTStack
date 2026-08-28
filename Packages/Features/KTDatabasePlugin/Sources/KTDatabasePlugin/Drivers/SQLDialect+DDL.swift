import Foundation

/// DDL composition. Identifiers are quoted via `quoteIdent` (the injection boundary); column types
/// ride raw because they can't be bound parameters, so `sanitizeType` restricts them to a charset
/// that can't smuggle further DDL. Every generated statement is shown to the user before it runs.
public extension SQLDialect {
    func createTable(schema: String, table: String, columns: [ColumnDefinition]) throws -> String {
        guard !columns.isEmpty else {
            throw DatabaseError.connection("CREATE TABLE needs at least one column")
        }
        let qualified = try qualifiedTable(schema: schema, table: table)
        var defs = try columns.map { try columnClause($0) }
        let primaryKeys = columns.filter(\.isPrimaryKey)
        if !primaryKeys.isEmpty {
            let cols = try primaryKeys.map { try quoteIdent($0.name) }.joined(separator: ", ")
            defs.append("PRIMARY KEY (\(cols))")
        }
        return "CREATE TABLE \(qualified) (\(defs.joined(separator: ", ")))"
    }

    func dropDatabase(_ name: String) throws -> String {
        try "DROP DATABASE \(quoteIdent(name))"
    }

    func dropTable(schema: String, table: String) throws -> String {
        try "DROP TABLE \(qualifiedTable(schema: schema, table: table))"
    }

    func addColumn(schema: String, table: String, column: ColumnDefinition) throws -> String {
        try "ALTER TABLE \(qualifiedTable(schema: schema, table: table)) "
            + "ADD COLUMN \(columnClause(column))"
    }

    func dropColumn(schema: String, table: String, column: String) throws -> String {
        try "ALTER TABLE \(qualifiedTable(schema: schema, table: table)) "
            + "DROP COLUMN \(quoteIdent(column))"
    }

    func renameTable(schema: String, table: String, to newName: String) throws -> String {
        try "ALTER TABLE \(qualifiedTable(schema: schema, table: table)) "
            + "RENAME TO \(qualifiedTable(schema: schema, table: newName))"
    }

    func truncateTable(schema: String, table: String) throws -> String {
        try "TRUNCATE TABLE \(qualifiedTable(schema: schema, table: table))"
    }

    func createView(schema: String, view: String, definition: String) throws -> String {
        let body = try Self.sanitizeViewDefinition(definition)
        return try "CREATE VIEW \(qualifiedTable(schema: schema, table: view)) AS \(body)"
    }

    func dropView(schema: String, view: String) throws -> String {
        try "DROP VIEW \(qualifiedTable(schema: schema, table: view))"
    }

    /// Escape a value into a single-quoted string literal. Used for modeled defaults and comments,
    /// which can't be bound parameters in DDL.
    func quoteString(_ value: String) throws -> String {
        guard !value.contains("\u{0}") else {
            throw DatabaseError.connection("Illegal character in SQL literal")
        }
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "''")
        return "'\(escaped)'"
    }

    private func columnClause(_ column: ColumnDefinition) throws -> String {
        let name = try quoteIdent(column.name)
        let type = try Self.sanitizeType(column.type)
        // A PRIMARY KEY column is implicitly NOT NULL in MySQL; emit NOT NULL explicitly for clarity.
        let nullability = (column.isNullable && !column.isPrimaryKey) ? "" : " NOT NULL"
        return "\(name) \(type)\(nullability)"
    }

    /// Column types can't be bound, so allow only a conservative charset: letters, digits, spaces,
    /// parens/comma/dot/underscore (covers `VARCHAR(255)`, `DECIMAL(10,2)`, `UNSIGNED`, etc.). Anything
    /// else (`;`, quotes, backticks, control chars) is rejected so a type string can't extend the DDL.
    static func sanitizeType(_ type: String) throws -> String {
        let trimmed = type.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            throw DatabaseError.connection("Empty column type")
        }
        let allowed = CharacterSet(
            charactersIn:
            "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 (),._"
        )
        guard trimmed.unicodeScalars.allSatisfy({ allowed.contains($0) }) else {
            throw DatabaseError.connection("Illegal character in column type")
        }
        return trimmed
    }

    /// A bare token used unquoted in DDL: charset, collation, engine name. Restrict to
    /// `[A-Za-z0-9_]` so it can't carry a space, quote or terminator into the statement.
    static func sanitizeToken(_ token: String) throws -> String {
        let trimmed = token.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            throw DatabaseError.connection("Empty token")
        }
        let allowed = CharacterSet(
            charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_"
        )
        guard trimmed.unicodeScalars.allSatisfy({ allowed.contains($0) }) else {
            throw DatabaseError.connection("Illegal character in token")
        }
        return trimmed
    }

    /// A raw expression used in DDL (view body, generated column, CHECK). It can't be bound, so
    /// block only statement terminators and control characters; the full text is always previewed.
    static func sanitizeExpression(_ expression: String) throws -> String {
        var trimmed = expression.trimmingCharacters(in: .whitespacesAndNewlines)
        // Bỏ một dấu ; ở cuối (thường do dán vào), rồi mới cấm ; để chặn ghép câu.
        if trimmed.hasSuffix(";") {
            trimmed = String(trimmed.dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard !trimmed.isEmpty else {
            throw DatabaseError.connection("Empty expression")
        }
        let allowedControls: Set<UInt32> = [0x09, 0x0A, 0x0D]
        guard !trimmed.contains(";"),
              !trimmed.unicodeScalars.contains(where: { $0.value < 0x20 && !allowedControls.contains($0.value) })
        else {
            throw DatabaseError.connection("Illegal character in expression")
        }
        return trimmed
    }

    static func sanitizeViewDefinition(_ definition: String) throws -> String {
        let trimmed = definition.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.lowercased().hasPrefix("select") else {
            throw DatabaseError.connection("A view definition must start with SELECT")
        }
        return try sanitizeExpression(trimmed)
    }
}
