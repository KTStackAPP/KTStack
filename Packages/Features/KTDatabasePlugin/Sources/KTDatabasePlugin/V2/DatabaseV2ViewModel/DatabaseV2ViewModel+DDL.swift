import Foundation

/// Ordered statements queued for the preview sheet before they run.
public struct DDLPreview: Identifiable {
    public let id = UUID()
    public let title: String
    public let statements: [DDLStatement]
}

public extension DatabaseV2ViewModel {
    private var ddlDialect: SQLDialect {
        SQLDialect.forKind(driver?.kind ?? .mysql)
    }

    func composeCreateTable(name: String, columns: [ColumnDefinition]) -> String {
        guard let database = selectedDatabase else {
            ddlError = "Select a database first."
            return ""
        }
        do {
            ddlError = nil
            return try ddlDialect.createTable(schema: database, table: name, columns: columns)
        } catch {
            ddlError = error.localizedDescription
            return ""
        }
    }

    func composeAddColumn(_ column: ColumnDefinition) -> String {
        guard let database = selectedDatabase, let table = selectedTable else {
            ddlError = "Select a table first."
            return ""
        }
        do {
            ddlError = nil
            return try ddlDialect.addColumn(schema: database, table: table.name, column: column)
        } catch {
            ddlError = error.localizedDescription
            return ""
        }
    }

    func composeDropColumn(_ column: String) -> String {
        guard let database = selectedDatabase, let table = selectedTable else {
            ddlError = "Select a table first."
            return ""
        }
        do {
            ddlError = nil
            return try ddlDialect.dropColumn(schema: database, table: table.name, column: column)
        } catch {
            ddlError = error.localizedDescription
            return ""
        }
    }

    func composeDropTable() -> String {
        guard let database = selectedDatabase, let table = selectedTable else {
            ddlError = "Select a table first."
            return ""
        }
        do {
            ddlError = nil
            return try ddlDialect.dropTable(schema: database, table: table.name)
        } catch {
            ddlError = error.localizedDescription
            return ""
        }
    }

    func runDDL(_ sql: String) async {
        guard !sql.isEmpty, let driver else { return }
        guard canApplySchema else {
            ddlError = "This connection is read-only."
            return
        }
        let token = generation
        isDDLBusy = true
        ddlError = nil
        defer { isDDLBusy = false }
        do {
            _ = try await driver.query(sql, database: selectedDatabase)
            guard token == generation else { return }
            await reloadAfterDDL()
        } catch {
            guard token == generation else { return }
            ddlError = error.localizedDescription
        }
    }

    func clearDDLError() {
        ddlError = nil
    }

    // Editor được phép đổi schema: driver quảng bá khả năng và profile không read-only.
    var canApplySchema: Bool {
        capabilities.canEditSchema && !connectionReadOnly
    }

    var ddlRenderer: MySQLDDLRenderer? {
        guard let database = selectedDatabase else { return nil }
        return MySQLDDLRenderer(dialect: ddlDialect, schema: database)
    }

    func makeSchemaDraft() -> SchemaEditDraft? {
        guard let table = selectedTable else { return nil }
        return SchemaEditDraft(tableName: table.name, columns: columns, indexes: indexes)
    }

    func renderCreateTable(_ draft: TableDefinitionDraft) -> DDLStatement? {
        guard let renderer = ddlRenderer else {
            ddlError = "Select a database first."
            return nil
        }
        do {
            ddlError = nil
            return try renderer.renderCreateTable(draft)
        } catch {
            ddlError = error.localizedDescription
            return nil
        }
    }

    // Xếp câu lệnh vào sheet xem trước; không có gì để chạy thì báo lỗi/không mở.
    func previewChanges(_ changes: [SchemaChange], title: String) {
        guard let table = selectedTable else { return }
        let statements = renderChanges(changes, table: table.name)
        guard !statements.isEmpty else { return }
        ddlPreview = DDLPreview(title: title, statements: statements)
    }

    func previewCreateTable(_ draft: TableDefinitionDraft) {
        guard let statement = renderCreateTable(draft) else { return }
        ddlPreview = DDLPreview(title: "Create Table", statements: [statement])
    }

    func applyPreview() async {
        guard let preview = ddlPreview else { return }
        await applyStatements(preview.statements)
        if ddlError == nil {
            ddlPreview = nil
        }
    }

    func cancelPreview() {
        ddlPreview = nil
    }

    func renderChanges(_ changes: [SchemaChange], table: String) -> [DDLStatement] {
        guard let renderer = ddlRenderer else {
            ddlError = "Select a database first."
            return []
        }
        do {
            ddlError = nil
            return try renderer.render(changes, table: table)
        } catch {
            ddlError = error.localizedDescription
            return []
        }
    }

    // Chạy tuần tự, dừng ở lỗi đầu tiên, báo số câu đã chạy rồi refresh schema thật.
    func applyStatements(_ statements: [DDLStatement]) async {
        guard !statements.isEmpty, let driver else { return }
        guard canApplySchema else {
            ddlError = "This connection is read-only."
            return
        }
        let token = generation
        isDDLBusy = true
        ddlError = nil
        defer { isDDLBusy = false }
        var applied = 0
        for statement in statements {
            do {
                _ = try await driver.query(statement.sql, database: selectedDatabase)
                guard token == generation else { return }
                applied += 1
            } catch {
                guard token == generation else { return }
                let detail = error.localizedDescription
                ddlError = applied == 0
                    ? detail
                    : "\(detail). \(applied) of \(statements.count) statement(s) applied before this failure."
                await reloadAfterDDL()
                return
            }
        }
        await reloadAfterDDL()
    }

    func renameTable(to newName: String) async {
        let trimmed = newName.trimmingCharacters(in: .whitespaces)
        guard let database = selectedDatabase, let table = selectedTable, !trimmed.isEmpty else { return }
        do {
            let sql = try ddlDialect.renameTable(schema: database, table: table.name, to: trimmed)
            await runDDL(sql)
        } catch {
            ddlError = error.localizedDescription
        }
    }

    func truncateTable() async {
        guard let database = selectedDatabase, let table = selectedTable else { return }
        do {
            let sql = try ddlDialect.truncateTable(schema: database, table: table.name)
            await runDDL(sql)
        } catch {
            ddlError = error.localizedDescription
        }
    }

    func createView(name: String, definition: String) async {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard let database = selectedDatabase, !trimmed.isEmpty else { return }
        do {
            let sql = try ddlDialect.createView(schema: database, view: trimmed, definition: definition)
            await runDDL(sql)
        } catch {
            ddlError = error.localizedDescription
        }
    }

    func dropView() async {
        guard let database = selectedDatabase, let table = selectedTable, table.isView else { return }
        do {
            let sql = try ddlDialect.dropView(schema: database, view: table.name)
            await runDDL(sql)
        } catch {
            ddlError = error.localizedDescription
        }
    }

    // Nguồn DDL chuẩn từ server (SHOW CREATE), không phải draft; refresh sau apply.
    func loadCreateTableDDL() async {
        guard let driver, let database = selectedDatabase, let table = selectedTable else {
            createTableDDL = nil
            return
        }
        let token = generation
        do {
            let verb = table.isView ? "SHOW CREATE VIEW" : "SHOW CREATE TABLE"
            let identifier = try ddlDialect.qualifiedTable(schema: database, table: table.name)
            let result = try await driver.query("\(verb) \(identifier)", database: database)
            guard token == generation else { return }
            // SHOW CREATE trả về ô cuối cùng của hàng đầu là câu lệnh tạo.
            createTableDDL = result.rows.first?.last?.displayText
        } catch {
            guard token == generation else { return }
            createTableDDL = nil
            ddlError = error.localizedDescription
        }
    }
}
