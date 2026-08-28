import Foundation

/// Schema introspection beyond columns: index listing for the table-structure view. Reuses the
/// public `query` path (literals quoted by `MySQLErrorMapper.quoteLiteral`), grouping the per-column
/// rows from `information_schema.STATISTICS` into one `IndexInfo` per index name.
public extension MySQLDriver {
    func allColumns(database: String) async throws -> [String: [String]] {
        let sql = try """
        SELECT TABLE_NAME, COLUMN_NAME FROM information_schema.COLUMNS \
        WHERE TABLE_SCHEMA = \(MySQLErrorMapper.quoteLiteral(database)) \
        ORDER BY TABLE_NAME, ORDINAL_POSITION
        """
        let result = try await query(sql, database: nil)
        var map: [String: [String]] = [:]
        for row in result.rows {
            guard row.count >= 2, let table = row[0].displayText, let column = row[1].displayText
            else { continue }
            map[table, default: []].append(column)
        }
        return map
    }

    func allColumnsDetailed(database: String) async throws -> [String: [ColumnInfo]] {
        let sql = try """
        SELECT TABLE_NAME, COLUMN_NAME, COLUMN_TYPE, IS_NULLABLE, COLUMN_KEY, COLUMN_DEFAULT \
        FROM information_schema.COLUMNS \
        WHERE TABLE_SCHEMA = \(MySQLErrorMapper.quoteLiteral(database)) \
        ORDER BY TABLE_NAME, ORDINAL_POSITION
        """
        let result = try await query(sql, database: nil)
        var map: [String: [ColumnInfo]] = [:]
        for row in result.rows {
            guard row.count >= 5, let table = row[0].displayText, let name = row[1].displayText
            else { continue }
            map[table, default: []].append(ColumnInfo(
                name: name,
                dataType: row[2].displayText ?? "",
                isNullable: row[3].displayText == "YES",
                isPrimaryKey: row[4].displayText == "PRI",
                defaultValue: row[5].displayText
            ))
        }
        return map
    }

    func foreignKeys(database: String) async throws -> [ForeignKeyRelation] {
        let sql = try """
        SELECT kcu.TABLE_NAME, kcu.COLUMN_NAME, kcu.REFERENCED_TABLE_NAME, kcu.REFERENCED_COLUMN_NAME, \
        kcu.CONSTRAINT_NAME, rc.UPDATE_RULE, rc.DELETE_RULE \
        FROM information_schema.KEY_COLUMN_USAGE kcu \
        LEFT JOIN information_schema.REFERENTIAL_CONSTRAINTS rc \
        ON rc.CONSTRAINT_SCHEMA = kcu.TABLE_SCHEMA AND rc.CONSTRAINT_NAME = kcu.CONSTRAINT_NAME \
        WHERE kcu.TABLE_SCHEMA = \(MySQLErrorMapper.quoteLiteral(database)) \
        AND kcu.REFERENCED_TABLE_NAME IS NOT NULL \
        ORDER BY kcu.TABLE_NAME, kcu.CONSTRAINT_NAME, kcu.ORDINAL_POSITION
        """
        let result = try await query(sql, database: nil)
        return ForeignKeyRowParser.parseRelational(result.rows)
    }

    // CHECK_CONSTRAINTS chỉ có trên MySQL 8.0.16+/MariaDB 10.2+; server cũ ném lỗi nên trả rỗng.
    func checkConstraints(database: String, table: String) async throws -> [CheckConstraintInfo] {
        let sql = try """
        SELECT cc.CONSTRAINT_NAME, cc.CHECK_CLAUSE \
        FROM information_schema.CHECK_CONSTRAINTS cc \
        JOIN information_schema.TABLE_CONSTRAINTS tc \
        ON tc.CONSTRAINT_SCHEMA = cc.CONSTRAINT_SCHEMA AND tc.CONSTRAINT_NAME = cc.CONSTRAINT_NAME \
        WHERE tc.TABLE_SCHEMA = \(MySQLErrorMapper.quoteLiteral(database)) \
        AND tc.TABLE_NAME = \(MySQLErrorMapper.quoteLiteral(table)) \
        AND tc.CONSTRAINT_TYPE = 'CHECK'
        """
        guard let result = try? await query(sql, database: nil) else { return [] }
        return result.rows.compactMap { row in
            guard row.count >= 2, let name = row[0].displayText, !name.isEmpty else { return nil }
            return CheckConstraintInfo(name: name, expression: row[1].displayText ?? "")
        }
    }

    func indexes(database: String, table: String) async throws -> [IndexInfo] {
        let sql = try """
        SELECT INDEX_NAME, COLUMN_NAME, NON_UNIQUE FROM information_schema.STATISTICS \
        WHERE TABLE_SCHEMA = \(MySQLErrorMapper.quoteLiteral(database)) \
        AND TABLE_NAME = \(MySQLErrorMapper.quoteLiteral(table)) \
        ORDER BY INDEX_NAME, SEQ_IN_INDEX
        """
        let result = try await query(sql, database: nil)

        var order: [String] = []
        var grouped: [String: (columns: [String], unique: Bool)] = [:]
        for row in result.rows {
            guard row.count >= 3, let name = row[0].displayText, let column = row[1].displayText else { continue }
            // NON_UNIQUE = 0 means the index enforces uniqueness.
            let unique = (row[2].displayText ?? "1") == "0"
            if grouped[name] == nil {
                order.append(name)
                grouped[name] = ([], unique)
            }
            grouped[name]?.columns.append(column)
        }
        return order.map { IndexInfo(name: $0, columns: grouped[$0]!.columns, isUnique: grouped[$0]!.unique) }
    }
}
