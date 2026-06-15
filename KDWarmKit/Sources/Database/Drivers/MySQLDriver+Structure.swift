import Foundation

/// Schema introspection beyond columns: index listing for the table-structure view. Reuses the
/// public `query` path (literals quoted by `MySQLErrorMapper.quoteLiteral`), grouping the per-column
/// rows from `information_schema.STATISTICS` into one `IndexInfo` per index name.
extension MySQLDriver {

    public func indexes(database: String, table: String) async throws -> [IndexInfo] {
        let sql = """
        SELECT INDEX_NAME, COLUMN_NAME, NON_UNIQUE FROM information_schema.STATISTICS \
        WHERE TABLE_SCHEMA = \(try MySQLErrorMapper.quoteLiteral(database)) \
        AND TABLE_NAME = \(try MySQLErrorMapper.quoteLiteral(table)) \
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
