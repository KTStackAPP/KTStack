import Foundation

public struct ForeignKeyPreview: Identifiable {
    public let id = UUID()
    public let relation: ForeignKeyRelation
    public let value: Cell
    public let result: QueryResult

    public var title: String {
        "\(relation.toTable).\(relation.toColumn) = \(value.displayText ?? "NULL")"
    }
}

public extension DatabaseV2ViewModel {
    func previewForeignKey(row: Int, column: Int) async {
        guard let result = rows, row >= 0, row < result.rows.count,
              column >= 0, column < result.columns.count,
              let driver, let database = selectedDatabase, let table = selectedTable else { return }
        let columnName = result.columns[column].name
        guard let relation = foreignKeys.first(where: { $0.fromTable == table.name && $0.fromColumn == columnName }) else { return }
        let value = result.rows[row][column]
        guard value != .null else { return }
        let token = generation
        editError = nil
        do {
            let statement = try SQLDialect.forKind(connectionKind ?? .mysql).browseSelect(
                schema: database, table: relation.toTable,
                filters: [FilterCondition(column: relation.toColumn, op: .equals, value: value)],
                sort: nil, limit: 100, offset: 0
            )
            let preview = try await driver.runSelect(statement, database: database)
            guard token == generation else { return }
            fkPreview = ForeignKeyPreview(relation: relation, value: value, result: preview)
        } catch {
            guard token == generation else { return }
            editError = error.localizedDescription
        }
    }

    func closeForeignKeyPreview() {
        fkPreview = nil
    }
}
