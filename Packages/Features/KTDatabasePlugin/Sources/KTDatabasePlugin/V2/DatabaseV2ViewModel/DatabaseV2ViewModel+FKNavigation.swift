import Foundation

/// Một bước trong lịch sử duyệt: bảng đang xem cộng bộ lọc FK (nil = xem toàn bảng từ sidebar).
public struct FKNavEntry: Equatable, Sendable {
    public let table: TableInfo
    public let filter: FilterCondition?
}

public extension DatabaseV2ViewModel {
    var activeFilter: FilterCondition? {
        navStack.indices.contains(navIndex) ? navStack[navIndex].filter : nil
    }

    var canGoBack: Bool { navIndex > 0 }
    var canGoForward: Bool { navIndex >= 0 && navIndex < navStack.count - 1 }

    var activeFilterLabel: String? {
        activeFilter.map { "\($0.column) = \($0.value.displayText ?? "NULL")" }
    }

    func fetchRows(
        driver: RelationalDriver, database: String, table: String, limit: Int, offset: Int
    ) async throws -> QueryResult {
        if let filter = activeFilter {
            let statement = try SQLDialect.forKind(connectionKind ?? .mysql).browseSelect(
                schema: database, table: table, filters: [filter], sort: nil, limit: limit, offset: offset
            )
            return try await driver.runSelect(statement, database: database)
        }
        return try await driver.paginatedRows(database: database, table: table, limit: limit, offset: offset)
    }

    // Đi theo khóa ngoại tại chỗ: đẩy một bước lịch sử mới rồi tải bảng đích đã lọc.
    func navigateForeignKey(row: Int, column: Int) {
        guard let result = rows, row >= 0, row < result.rows.count,
              column >= 0, column < result.columns.count, let table = selectedTable else { return }
        let columnName = result.columns[column].name
        guard let relation = foreignKeys.first(where: { $0.fromTable == table.name && $0.fromColumn == columnName }) else { return }
        let value = result.rows[row][column]
        guard value != .null else { return }
        let target = tables.first(where: { $0.name == relation.toTable }) ?? TableInfo(name: relation.toTable)
        let entry = FKNavEntry(
            table: target, filter: FilterCondition(column: relation.toColumn, op: .equals, value: value)
        )
        if navIndex < navStack.count - 1 { navStack.removeSubrange((navIndex + 1)...) }
        navStack.append(entry)
        navIndex = navStack.count - 1
        loadNavEntry()
    }

    func goBack() {
        guard canGoBack else { return }
        navIndex -= 1
        loadNavEntry()
    }

    func goForward() {
        guard canGoForward else { return }
        navIndex += 1
        loadNavEntry()
    }
}
