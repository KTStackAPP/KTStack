import Foundation

/// Turns typed schema models into MySQL/MariaDB DDL. Identifiers go through `SQLDialect.quoteIdent`,
/// types through `sanitizeType`, bare tokens (charset/collation/engine) through `sanitizeToken`,
/// modeled defaults and comments through `quoteString`, and raw expressions (generated columns,
/// CHECK, view body) through `sanitizeExpression`. One statement per change so a partial apply can
/// report exactly which changes ran. Every statement is shown before it runs.
public struct MySQLDDLRenderer {
    public let dialect: SQLDialect
    public let schema: String

    public init(dialect: SQLDialect, schema: String) {
        self.dialect = dialect
        self.schema = schema
    }

    public func renderCreateTable(_ draft: TableDefinitionDraft) throws -> DDLStatement {
        guard !draft.columns.isEmpty else {
            throw DatabaseError.connection("CREATE TABLE needs at least one column")
        }
        let qualified = try dialect.qualifiedTable(schema: schema, table: draft.name)
        var defs: [String] = try draft.columns.map {
            try columnClause($0, forcedNotNull: draft.primaryKey.contains($0.name))
        }
        if !draft.primaryKey.isEmpty {
            defs.append(try "PRIMARY KEY (\(quotedList(draft.primaryKey)))")
        }
        defs.append(contentsOf: try draft.indexes.map { try indexClause($0) })
        defs.append(contentsOf: try draft.foreignKeys.map { try foreignKeyClause($0) })
        defs.append(contentsOf: try draft.checks.map { try checkClause($0) })
        var sql = "CREATE TABLE \(qualified) (\(defs.joined(separator: ", ")))"
        let options = try tableOptionClause(draft.options)
        if !options.isEmpty {
            sql += " \(options)"
        }
        return DDLStatement(sql: sql, summary: "Create table \(quotedName(draft.name))")
    }

    public func render(_ changes: [SchemaChange], table: String) throws -> [DDLStatement] {
        try changes.map { try render($0, table: table) }
    }

    public func render(_ change: SchemaChange, table: String) throws -> DDLStatement {
        let qualified = try dialect.qualifiedTable(schema: schema, table: table)
        let alter = "ALTER TABLE \(qualified) "
        switch change {
        case let .addColumn(column, after):
            var sql = try alter + "ADD COLUMN \(columnClause(column))"
            if let after, !after.isEmpty {
                sql += try " AFTER \(dialect.quoteIdent(after))"
            }
            return DDLStatement(sql: sql, summary: "Add column \(quotedName(column.name))")
        case let .modifyColumn(original, column):
            let sql = try alter + "CHANGE COLUMN \(dialect.quoteIdent(original)) \(columnClause(column))"
            let summary = original == column.name
                ? "Modify column \(quotedName(original))"
                : "Rename column \(quotedName(original)) to \(quotedName(column.name))"
            return DDLStatement(sql: sql, summary: summary)
        case let .dropColumn(name):
            let sql = try alter + "DROP COLUMN \(dialect.quoteIdent(name))"
            return DDLStatement(sql: sql, summary: "Drop column \(quotedName(name))", isDestructive: true)
        case let .setPrimaryKey(columns):
            guard !columns.isEmpty else {
                throw DatabaseError.connection("PRIMARY KEY needs at least one column")
            }
            let sql = try alter + "ADD PRIMARY KEY (\(quotedList(columns)))"
            return DDLStatement(sql: sql, summary: "Set primary key")
        case .dropPrimaryKey:
            return DDLStatement(sql: alter + "DROP PRIMARY KEY", summary: "Drop primary key", isDestructive: true)
        case let .addIndex(index):
            let sql = try alter + "ADD \(indexClause(index))"
            return DDLStatement(sql: sql, summary: "Add index \(indexLabel(index))")
        case let .dropIndex(name):
            let sql = try alter + "DROP INDEX \(dialect.quoteIdent(name))"
            return DDLStatement(sql: sql, summary: "Drop index \(quotedName(name))", isDestructive: true)
        case let .addForeignKey(fk):
            let sql = try alter + "ADD " + foreignKeyClause(fk)
            return DDLStatement(sql: sql, summary: "Add foreign key \(quotedName(fk.name))")
        case let .dropForeignKey(name):
            let sql = try alter + "DROP FOREIGN KEY \(dialect.quoteIdent(name))"
            return DDLStatement(sql: sql, summary: "Drop foreign key \(quotedName(name))", isDestructive: true)
        case let .addCheck(check):
            let sql = try alter + "ADD " + checkClause(check)
            return DDLStatement(sql: sql, summary: "Add check \(quotedName(check.name))")
        case let .dropCheck(name):
            // DROP CONSTRAINT drops a named CHECK on both MySQL 8.0.19+ and MariaDB.
            let sql = try alter + "DROP CONSTRAINT \(dialect.quoteIdent(name))"
            return DDLStatement(sql: sql, summary: "Drop check \(quotedName(name))", isDestructive: true)
        case let .setTableOptions(options):
            let clause = try tableOptionClause(options)
            guard !clause.isEmpty else {
                throw DatabaseError.connection("No table options to apply")
            }
            return DDLStatement(sql: alter + clause, summary: "Set table options")
        }
    }

    // MARK: - Clauses

    func columnClause(_ column: ColumnDraft, forcedNotNull: Bool = false) throws -> String {
        var parts: [String] = try [dialect.quoteIdent(column.name), SQLDialect.sanitizeType(column.type)]
        if let charset = column.charset {
            parts.append(try "CHARACTER SET \(SQLDialect.sanitizeToken(charset))")
        }
        if let collation = column.collation {
            parts.append(try "COLLATE \(SQLDialect.sanitizeToken(collation))")
        }
        if let generated = column.generated {
            let expr = try SQLDialect.sanitizeExpression(generated.expression)
            parts.append("GENERATED ALWAYS AS (\(expr)) \(generated.kind.rawValue)")
        }
        if forcedNotNull || !column.isNullable {
            parts.append("NOT NULL")
        }
        // Generated columns take no DEFAULT, no ON UPDATE and no AUTO_INCREMENT.
        if column.generated == nil {
            if let clause = try defaultClause(column.defaultValue) {
                parts.append(clause)
            }
            if column.onUpdateCurrentTimestamp {
                parts.append("ON UPDATE CURRENT_TIMESTAMP")
            }
            if column.isAutoIncrement {
                parts.append("AUTO_INCREMENT")
            }
        }
        if let comment = column.comment, !comment.isEmpty {
            parts.append(try "COMMENT \(dialect.quoteString(comment))")
        }
        return parts.joined(separator: " ")
    }

    private func defaultClause(_ value: ColumnDefault) throws -> String? {
        switch value {
        case .none:
            return nil
        case .null:
            return "DEFAULT NULL"
        case let .text(text):
            return try "DEFAULT \(dialect.quoteString(text))"
        case let .number(number):
            return try "DEFAULT \(sanitizeNumber(number))"
        case .currentTimestamp:
            return "DEFAULT CURRENT_TIMESTAMP"
        case let .expression(expression):
            return try "DEFAULT (\(SQLDialect.sanitizeExpression(expression)))"
        }
    }

    private func indexClause(_ index: IndexDraft) throws -> String {
        guard !index.columns.isEmpty else {
            throw DatabaseError.connection("An index needs at least one column")
        }
        let keyword = index.isUnique ? "UNIQUE INDEX" : "INDEX"
        let name = index.name.isEmpty ? "" : try "\(dialect.quoteIdent(index.name)) "
        return try "\(keyword) \(name)(\(quotedList(index.columns)))"
    }

    private func foreignKeyClause(_ fk: ForeignKeyDraft) throws -> String {
        guard !fk.columns.isEmpty, fk.columns.count == fk.refColumns.count else {
            throw DatabaseError.connection("A foreign key needs matching local and referenced columns")
        }
        let refTable = try dialect.qualifiedTable(schema: schema, table: fk.refTable)
        var clause = try "CONSTRAINT \(dialect.quoteIdent(fk.name)) FOREIGN KEY (\(quotedList(fk.columns))) "
            + "REFERENCES \(refTable) (\(quotedList(fk.refColumns)))"
        clause += " ON DELETE \(fk.onDelete.rawValue) ON UPDATE \(fk.onUpdate.rawValue)"
        return clause
    }

    private func checkClause(_ check: CheckConstraintDraft) throws -> String {
        let expr = try SQLDialect.sanitizeExpression(check.expression)
        return try "CONSTRAINT \(dialect.quoteIdent(check.name)) CHECK (\(expr))"
    }

    private func tableOptionClause(_ options: TableOptionDraft) throws -> String {
        var parts: [String] = []
        if let engine = options.engine {
            parts.append(try "ENGINE=\(SQLDialect.sanitizeToken(engine))")
        }
        if let charset = options.charset {
            parts.append(try "DEFAULT CHARSET=\(SQLDialect.sanitizeToken(charset))")
        }
        if let collation = options.collation {
            parts.append(try "COLLATE=\(SQLDialect.sanitizeToken(collation))")
        }
        if let autoIncrement = options.autoIncrement {
            parts.append("AUTO_INCREMENT=\(autoIncrement)")
        }
        if let comment = options.comment {
            parts.append(try "COMMENT=\(dialect.quoteString(comment))")
        }
        return parts.joined(separator: " ")
    }

    // MARK: - Helpers

    private func quotedList(_ names: [String]) throws -> String {
        try names.map { try dialect.quoteIdent($0) }.joined(separator: ", ")
    }

    private func quotedName(_ name: String) -> String {
        (try? dialect.quoteIdent(name)) ?? name
    }

    private func indexLabel(_ index: IndexDraft) -> String {
        index.name.isEmpty ? "(\(index.columns.joined(separator: ", ")))" : quotedName(index.name)
    }

    private func sanitizeNumber(_ number: String) throws -> String {
        let trimmed = number.trimmingCharacters(in: .whitespaces)
        let allowed = CharacterSet(charactersIn: "0123456789.-+eE")
        guard !trimmed.isEmpty, Double(trimmed) != nil,
              trimmed.unicodeScalars.allSatisfy({ allowed.contains($0) })
        else {
            throw DatabaseError.connection("Illegal numeric default")
        }
        return trimmed
    }
}
