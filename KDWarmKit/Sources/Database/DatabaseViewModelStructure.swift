import Foundation

/// Table-structure browsing and DDL. DDL always follows compose → show → confirm: a `prepare…` call
/// only stages SQL in `pendingDDL` (the UI shows it verbatim); nothing reaches the server until
/// `confirmDDL()`. Composition errors land in `ddlError` rather than emitting half-formed SQL.
public extension DatabaseViewModel {

    private var ddlDialect: SQLDialect { SQLDialect.forKind(selectedProfile?.kind ?? .mysql) }

    public var canDropDatabase: Bool {
        selectedProfile?.kind == .mysql || selectedProfile?.kind == .postgres
    }

    // MARK: - Structure

    /// Load columns (if not already loaded) plus indexes for the selected table.
    func loadStructure() async {
        guard let driver, let database = selectedDatabase, let table = selectedTable else {
            currentIndexes = []
            return
        }
        if currentColumns.isEmpty {
            currentColumns = (try? await driver.columns(database: database, table: table.name)) ?? []
        }
        currentIndexes = (try? await driver.indexes(database: database, table: table.name)) ?? []
    }

    // MARK: - DDL composition (staged, not run)

    func prepareCreateTable(name: String, columns: [ColumnDefinition]) {
        stageDDL { try ddlDialect.createTable(schema: requireDatabase(), table: name, columns: columns) }
    }

    func prepareAddColumn(_ column: ColumnDefinition) {
        stageDDL {
            let (db, table) = try requireTable()
            return try ddlDialect.addColumn(schema: db, table: table, column: column)
        }
    }

    func prepareDropColumn(_ column: String) {
        stageDDL {
            let (db, table) = try requireTable()
            return try ddlDialect.dropColumn(schema: db, table: table, column: column)
        }
    }

    func prepareDropDatabase(_ name: String) {
        stageDDL { try ddlDialect.dropDatabase(name) }
    }

    func confirmDropDatabase(_ name: String) async {
        guard let sql = pendingDDL else { return }
        pendingDDL = nil
        guard !isReadOnlyConnection else { ddlError = "This connection is read-only."; return }
        await runSQL(sql, confirmed: true)
        if resultError == nil {
            if let refreshed = try? await driver?.listDatabases() {
                databases = refreshed
            }
            if selectedDatabase == name { clearSelectedDatabase() }
        }
    }

    func prepareDropTable() {
        stageDDL {
            let (db, table) = try requireTable()
            return try ddlDialect.dropTable(schema: db, table: table)
        }
    }

    func cancelDDL() { pendingDDL = nil }

    func clearDDLError() { ddlError = nil }

    /// Run the staged DDL through the shared SQL runner (confirmed, so the destructive guard is
    /// bypassed — the user already saw and confirmed the exact statement), then refresh the schema.
    func confirmDDL() async {
        guard let sql = pendingDDL else { return }
        pendingDDL = nil
        // Defense-in-depth: the UI hides DDL actions on a read-only connection, but refuse here too
        // so a staged statement can never run against a connection the user marked read-only.
        guard !isReadOnlyConnection else {
            ddlError = "This connection is read-only."
            return
        }
        await runSQL(sql, confirmed: true)
        if resultError == nil {
            if let database = selectedDatabase {
                tables = (try? await driver?.listTables(database: database)) ?? tables
            }
            await loadStructure()
        }
    }

    // MARK: - Helpers

    private func stageDDL(_ build: () throws -> String) {
        do {
            ddlError = nil
            pendingDDL = try build()
        } catch {
            pendingDDL = nil
            ddlError = Self.asDatabaseError(error).message
        }
    }

    private func requireDatabase() throws -> String {
        guard let database = selectedDatabase else {
            throw DatabaseError.connection("Pick a database first.")
        }
        return database
    }

    private func requireTable() throws -> (database: String, table: String) {
        guard let database = selectedDatabase, let table = selectedTable else {
            throw DatabaseError.connection("Pick a table first.")
        }
        return (database, table.name)
    }
}
