import Foundation

public enum FilterOperator: String, Sendable, CaseIterable, Codable {
    case equals
    case notEquals
    case contains
    case greaterThan
    case lessThan
    case isNull
    case isNotNull

    public var bindsValue: Bool {
        switch self {
        case .isNull, .isNotNull: false
        default: true
        }
    }

    public var symbol: String {
        switch self {
        case .equals: "="
        case .notEquals: "≠"
        case .contains: "contains"
        case .greaterThan: ">"
        case .lessThan: "<"
        case .isNull: "IS NULL"
        case .isNotNull: "IS NOT NULL"
        }
    }
}

public struct FilterCondition: Sendable, Equatable, Codable {
    public let column: String
    public let op: FilterOperator
    public let value: Cell

    public init(column: String, op: FilterOperator, value: Cell = .null) {
        self.column = column
        self.op = op
        self.value = value
    }
}

public struct SortSpec: Sendable, Equatable {
    public let column: String
    public let ascending: Bool

    public init(column: String, ascending: Bool) {
        self.column = column
        self.ascending = ascending
    }
}

public extension SQLDialect {
    func browseSelect(
        schema: String,
        table: String,
        filters: [FilterCondition],
        sort: SortSpec?,
        limit: Int,
        offset: Int
    ) throws -> DMLStatement {
        try browseSelect(
            schema: schema, table: table, filters: filters,
            sorts: sort.map { [$0] } ?? [], limit: limit, offset: offset
        )
    }

    func browseSelect(
        schema: String,
        table: String,
        filters: [FilterCondition],
        sorts: [SortSpec],
        limit: Int,
        offset: Int
    ) throws -> DMLStatement {
        let qualified = try qualifiedTable(schema: schema, table: table)
        var binds: [Cell] = []
        var sql = "SELECT * FROM \(qualified)"

        if let clause = try whereClause(filters, binds: &binds) {
            sql += " WHERE " + clause
        }
        if let order = try orderByClause(sorts) {
            sql += " ORDER BY " + order
        }

        sql += " LIMIT \(max(1, limit)) OFFSET \(max(0, offset))"
        return DMLStatement(sql: sql, binds: binds)
    }

    func countSelect(schema: String, table: String, filters: [FilterCondition]) throws -> DMLStatement {
        let qualified = try qualifiedTable(schema: schema, table: table)
        var binds: [Cell] = []
        var sql = "SELECT COUNT(*) FROM \(qualified)"
        if let clause = try whereClause(filters, binds: &binds) {
            sql += " WHERE " + clause
        }
        return DMLStatement(sql: sql, binds: binds)
    }

    // WHERE fragment với placeholder, bỏ binds: preview an toàn, không lộ giá trị literal.
    func whereClausePreview(_ filters: [FilterCondition]) throws -> String? {
        var binds: [Cell] = []
        return try whereClause(filters, binds: &binds)
    }

    private func whereClause(_ filters: [FilterCondition], binds: inout [Cell]) throws -> String? {
        guard !filters.isEmpty else { return nil }
        return try filters.map { try clause(for: $0, binds: &binds) }.joined(separator: " AND ")
    }

    private func orderByClause(_ sorts: [SortSpec]) throws -> String? {
        guard !sorts.isEmpty else { return nil }
        return try sorts
            .map { try "\(quoteIdent($0.column)) \($0.ascending ? "ASC" : "DESC")" }
            .joined(separator: ", ")
    }

    private func clause(for filter: FilterCondition, binds: inout [Cell]) throws -> String {
        let column = try quoteIdent(filter.column)
        switch filter.op {
        case .isNull: return "\(column) IS NULL"
        case .isNotNull: return "\(column) IS NOT NULL"
        case .equals: return binary(column, "=", filter.value, &binds)
        case .notEquals: return binary(column, "<>", filter.value, &binds)
        case .greaterThan: return binary(column, ">", filter.value, &binds)
        case .lessThan: return binary(column, "<", filter.value, &binds)
        case .contains:
            binds.append(.text("%\(filter.value.displayText ?? "")%"))
            return "\(column) LIKE \(placeholderStyle.placeholder(binds.count))"
        }
    }

    private func binary(_ column: String, _ op: String, _ value: Cell, _ binds: inout [Cell]) -> String {
        binds.append(value)
        return "\(column) \(op) \(placeholderStyle.placeholder(binds.count))"
    }
}
