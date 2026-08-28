import Foundation

/// Một bước trong lịch sử duyệt: bảng đang xem cộng bộ lọc đang áp (rỗng = xem toàn bảng).
public struct FKNavEntry: Equatable, Sendable {
    public let table: TableInfo
    public var filters: [FilterCondition]
}

public extension DatabaseV2ViewModel {
    var activeFilters: [FilterCondition] {
        navStack.indices.contains(navIndex) ? navStack[navIndex].filters : []
    }

    var canGoBack: Bool { navIndex > 0 }
    var canGoForward: Bool { navIndex >= 0 && navIndex < navStack.count - 1 }

    var activeFilterLabel: String? {
        guard !activeFilters.isEmpty else { return nil }
        return activeFilters.map(filterConditionLabel).joined(separator: " · ")
    }

    private func filterConditionLabel(_ condition: FilterCondition) -> String {
        switch condition.op {
        case .isNull: return "\(condition.column) IS NULL"
        case .isNotNull: return "\(condition.column) IS NOT NULL"
        default: return "\(condition.column) \(condition.op.symbol) \(condition.value.displayText ?? "NULL")"
        }
    }

    func fetchRows(
        driver: RelationalDriver, database: String, table: String, limit: Int, offset: Int
    ) async throws -> QueryResult {
        if !activeFilters.isEmpty {
            let statement = try SQLDialect.forKind(connectionKind ?? .mysql).browseSelect(
                schema: database, table: table, filters: activeFilters, sort: nil, limit: limit, offset: offset
            )
            return try await driver.runSelect(statement, database: database)
        }
        return try await driver.paginatedRows(database: database, table: table, limit: limit, offset: offset)
    }

    // Áp bộ lọc do người dùng đặt lên bước hiện tại rồi tải lại (không tạo bước lịch sử mới).
    func applyFilters(_ conditions: [FilterCondition]) {
        guard navStack.indices.contains(navIndex) else { return }
        navStack[navIndex].filters = conditions
        loadNavEntry()
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
            table: target, filters: [FilterCondition(column: relation.toColumn, op: .equals, value: value)]
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
