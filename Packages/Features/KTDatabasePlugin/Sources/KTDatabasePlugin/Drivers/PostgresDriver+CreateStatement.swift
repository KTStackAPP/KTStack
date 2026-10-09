import Foundation
import PostgresNIO

/// One column as `pg_attribute` describes it, enough to print its line in a CREATE TABLE.
struct PostgresColumnDDL: Equatable {
    let name: String
    let type: String
    let notNull: Bool
    let defaultExpression: String?
    let identity: String
    let generated: String
}

/// Postgres has no SHOW CREATE, so the statement is rebuilt from server-rendered fragments
/// (`format_type`, `pg_get_expr`, `pg_get_constraintdef`, `pg_get_indexdef`, `pg_get_viewdef`).
/// It covers columns, constraints and indexes; comments, ownership, partitioning and inheritance are left out.
public extension PostgresDriver {
    func createStatement(database: String, table: TableInfo) async throws -> String? {
        let qualified = try dialect.qualifiedTable(schema: database, table: table.name)
        if table.isView {
            let rows = try await catalogRows("""
            SELECT pg_get_viewdef(c.oid, true) FROM pg_class c \
            JOIN pg_namespace n ON n.oid = c.relnamespace \
            WHERE n.nspname = $1 AND c.relname = $2
            """, database: database, table: table.name)
            guard let definition = rows.first?.first?.displayText else { return nil }
            return Self.renderView(qualifiedName: qualified, definition: definition)
        }

        let columnRows = try await catalogRows("""
        SELECT a.attname, format_type(a.atttypid, a.atttypmod), \
        CASE WHEN a.attnotnull THEN 'YES' ELSE 'NO' END, \
        pg_get_expr(d.adbin, d.adrelid), a.attidentity::text, a.attgenerated::text \
        FROM pg_attribute a \
        JOIN pg_class c ON c.oid = a.attrelid \
        JOIN pg_namespace n ON n.oid = c.relnamespace \
        LEFT JOIN pg_attrdef d ON d.adrelid = a.attrelid AND d.adnum = a.attnum \
        WHERE n.nspname = $1 AND c.relname = $2 AND a.attnum > 0 AND NOT a.attisdropped \
        ORDER BY a.attnum
        """, database: database, table: table.name)
        let columns = columnRows.compactMap { row -> PostgresColumnDDL? in
            guard row.count >= 6, let name = row[0].displayText else { return nil }
            return PostgresColumnDDL(
                name: name,
                type: row[1].displayText ?? "",
                notNull: row[2].displayText == "YES",
                defaultExpression: row[3].displayText,
                identity: row[4].displayText ?? "",
                generated: row[5].displayText ?? ""
            )
        }
        guard !columns.isEmpty else { return nil }

        let constraintRows = try await catalogRows("""
        SELECT con.conname, pg_get_constraintdef(con.oid, true) FROM pg_constraint con \
        JOIN pg_class c ON c.oid = con.conrelid \
        JOIN pg_namespace n ON n.oid = c.relnamespace \
        WHERE n.nspname = $1 AND c.relname = $2 AND con.contype IN ('p', 'u', 'c', 'f', 'x') \
        ORDER BY CASE con.contype WHEN 'p' THEN 0 WHEN 'u' THEN 1 WHEN 'c' THEN 2 WHEN 'f' THEN 3 ELSE 4 END, \
        con.conname
        """, database: database, table: table.name)
        let constraints = constraintRows.compactMap { row -> (name: String, definition: String)? in
            guard row.count >= 2, let name = row[0].displayText, let definition = row[1].displayText
            else { return nil }
            return (name, definition)
        }

        // Index đã thuộc PK/UNIQUE/EXCLUDE thì constraint in rồi, bỏ để khỏi lặp.
        let indexRows = try await catalogRows("""
        SELECT pg_get_indexdef(ix.indexrelid) FROM pg_index ix \
        JOIN pg_class c ON c.oid = ix.indrelid \
        JOIN pg_namespace n ON n.oid = c.relnamespace \
        JOIN pg_class i ON i.oid = ix.indexrelid \
        WHERE n.nspname = $1 AND c.relname = $2 AND NOT EXISTS ( \
          SELECT 1 FROM pg_constraint con \
          WHERE con.conindid = ix.indexrelid AND con.conrelid = ix.indrelid \
        ) ORDER BY i.relname
        """, database: database, table: table.name)
        let indexes = indexRows.compactMap { $0.first?.displayText }

        return try Self.renderTable(
            qualifiedName: qualified,
            columns: columns,
            constraints: constraints,
            indexes: indexes
        )
    }

    private func catalogRows(_ sql: String, database: String, table: String) async throws -> [[Cell]] {
        var binds = PostgresBindings()
        binds.append(database)
        binds.append(table)
        return try await runQuery(PostgresQuery(unsafeSQL: sql, binds: binds)).rows
    }

    internal static func renderView(qualifiedName: String, definition: String) -> String {
        "CREATE VIEW \(qualifiedName) AS\n\(terminated(definition))"
    }

    internal static func renderTable(
        qualifiedName: String,
        columns: [PostgresColumnDDL],
        constraints: [(name: String, definition: String)],
        indexes: [String]
    ) throws -> String {
        let dialect = SQLDialect.forKind(.postgres)
        var lines = try columns.map { try columnLine($0, dialect: dialect) }
        lines += try constraints.map { "CONSTRAINT \(try dialect.quoteIdent($0.name)) \($0.definition)" }
        var statement = "CREATE TABLE \(qualifiedName) (\n"
            + lines.map { "    \($0)" }.joined(separator: ",\n")
            + "\n);"
        if !indexes.isEmpty {
            statement += "\n\n" + indexes.map(terminated).joined(separator: "\n")
        }
        return statement
    }

    private static func columnLine(_ column: PostgresColumnDDL, dialect: SQLDialect) throws -> String {
        var parts = [try dialect.quoteIdent(column.name), column.type]
        switch column.identity {
        case "a": parts.append("GENERATED ALWAYS AS IDENTITY")
        case "d": parts.append("GENERATED BY DEFAULT AS IDENTITY")
        default: break
        }
        if column.generated == "s", let expression = column.defaultExpression {
            parts.append("GENERATED ALWAYS AS (\(expression)) STORED")
        }
        if column.notNull {
            parts.append("NOT NULL")
        }
        if column.generated.isEmpty, let expression = column.defaultExpression {
            parts.append("DEFAULT \(expression)")
        }
        return parts.joined(separator: " ")
    }

    private static func terminated(_ statement: String) -> String {
        let trimmed = statement.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.hasSuffix(";") ? trimmed : trimmed + ";"
    }
}
