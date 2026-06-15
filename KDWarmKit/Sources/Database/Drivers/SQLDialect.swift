import Foundation

public struct SQLDialect: Sendable {
   
    public let quote: Character

    public static func forKind(_ kind: DatabaseKind) -> SQLDialect {
        switch kind {
        case .mysql:                       return SQLDialect(quote: "`")
        case .postgres, .sqlite, .mongodb: return SQLDialect(quote: "\"")
        }
    }

  
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

   
    public func qualifiedTable(schema: String, table: String) throws -> String {
        "\(try quoteIdent(schema)).\(try quoteIdent(table))"
    }


    public func paginate(_ sql: String, limit: Int, offset: Int) -> String {
        let safeLimit = max(1, limit)
        let safeOffset = max(0, offset)
        return "\(sql) LIMIT \(safeLimit) OFFSET \(safeOffset)"
    }

    // MARK: - DML composition (parameterized)

    public func insert(schema: String, table: String, values: [ColumnValue]) throws -> DMLStatement {
        guard !values.isEmpty else {
            throw DatabaseError.connection("INSERT needs at least one column")
        }
        let qualified = try qualifiedTable(schema: schema, table: table)
        let columns = try values.map { try quoteIdent($0.column) }.joined(separator: ", ")
        let placeholders = Array(repeating: "?", count: values.count).joined(separator: ", ")
        return DMLStatement(sql: "INSERT INTO \(qualified) (\(columns)) VALUES (\(placeholders))",
                            binds: values.map(\.value))
    }

 
    public func update(schema: String, table: String,
                       values: [ColumnValue], key: [ColumnValue]) throws -> DMLStatement {
        guard !values.isEmpty else {
            throw DatabaseError.connection("UPDATE needs at least one column to set")
        }
        try requireUsableKey(key)
        let qualified = try qualifiedTable(schema: schema, table: table)
        let setClause = try values.map { "\(try quoteIdent($0.column)) = ?" }.joined(separator: ", ")
        let whereClause = try key.map { "\(try quoteIdent($0.column)) = ?" }.joined(separator: " AND ")
        return DMLStatement(sql: "UPDATE \(qualified) SET \(setClause) WHERE \(whereClause)",
                            binds: values.map(\.value) + key.map(\.value))
    }


    public func delete(schema: String, table: String, key: [ColumnValue]) throws -> DMLStatement {
        try requireUsableKey(key)
        let qualified = try qualifiedTable(schema: schema, table: table)
        let whereClause = try key.map { "\(try quoteIdent($0.column)) = ?" }.joined(separator: " AND ")
        return DMLStatement(sql: "DELETE FROM \(qualified) WHERE \(whereClause)",
                            binds: key.map(\.value))
    }

    private func requireUsableKey(_ key: [ColumnValue]) throws {
        guard !key.isEmpty else {
            throw DatabaseError.connection("Refusing an UPDATE/DELETE with no key (would affect every row)")
        }
        guard !key.contains(where: { $0.value == .null }) else {
            throw DatabaseError.connection("A NULL key can't identify a single row")
        }
    }
}


public struct DMLStatement: Sendable, Equatable {
    public let sql: String
    public let binds: [Cell]

    public init(sql: String, binds: [Cell]) {
        self.sql = sql
        self.binds = binds
    }
}
