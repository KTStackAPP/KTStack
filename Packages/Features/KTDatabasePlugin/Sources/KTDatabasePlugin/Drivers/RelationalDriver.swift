import Foundation

public protocol RelationalDriver: DatabaseDriver {
    var capabilities: DriverCapabilities { get }

    func listDatabases() async throws -> [DatabaseInfo]

    func backupDatabaseNames() async throws -> [String]

    func listTables(database: String) async throws -> [TableInfo]

    func columns(database: String, table: String) async throws -> [ColumnInfo]

    func allColumns(database: String) async throws -> [String: [String]]

    func allColumnsDetailed(database: String) async throws -> [String: [ColumnInfo]]

    func indexes(database: String, table: String) async throws -> [IndexInfo]

    func foreignKeys(database: String) async throws -> [ForeignKeyRelation]

    func checkConstraints(database: String, table: String) async throws -> [CheckConstraintInfo]

    func createStatement(database: String, table: TableInfo) async throws -> String?

    func query(_ sql: String, database: String?) async throws -> QueryResult

    func paginatedRows(database: String, table: String, limit: Int, offset: Int) async throws -> QueryResult

    func openSession() async throws

    func closeSession() async

    func cancelCurrentQuery() async

    func runSelect(_ statement: DMLStatement, database: String?) async throws -> QueryResult

    func insert(database: String, table: String, values: [ColumnValue]) async throws

    func update(database: String, table: String, values: [ColumnValue], key: [ColumnValue]) async throws

    func delete(database: String, table: String, key: [ColumnValue]) async throws

    func executeTransaction(_ steps: [WriteStep], database: String) async throws

    func serverVersion() async throws -> String
}

public extension RelationalDriver {
    // Mặc định relational: hỗ trợ đủ; driver có giới hạn tự override (SQLite không hủy được query).
    var capabilities: DriverCapabilities { DriverCapabilities() }

    func cancelCurrentQuery() async {}

    // Engine không introspect CHECK (Postgres/SQLite/Mongo, hoặc MySQL cũ) trả rỗng.
    func checkConstraints(database: String, table: String) async throws -> [CheckConstraintInfo] { [] }

    // SHOW CREATE chỉ MySQL/MariaDB có; Postgres và SQLite tự override.
    func createStatement(database: String, table: TableInfo) async throws -> String? {
        guard kind == .mysql else {
            throw DatabaseError.connection("DDL source isn't available for this engine")
        }
        let verb = table.isView ? "SHOW CREATE VIEW" : "SHOW CREATE TABLE"
        let identifier = try SQLDialect.forKind(kind).qualifiedTable(schema: database, table: table.name)
        let result = try await query("\(verb) \(identifier)", database: database)
        // Cột thứ hai là câu lệnh tạo; SHOW CREATE VIEW còn thêm charset/collation phía sau.
        guard let row = result.rows.first, row.count > 1 else { return nil }
        return row[1].displayText
    }

    // Batch commit chỉ bật cho engine MVP (MySQL/MariaDB); engine khác override khi có nhu cầu.
    func executeTransaction(_ steps: [WriteStep], database: String) async throws {
        throw DatabaseError.connection("Batch commit isn't supported for this engine yet")
    }

    // Phiên bản server để hiện trong pill trạng thái; SQL theo engine, rỗng nếu không rõ.
    func serverVersion() async throws -> String {
        let sql: String
        switch kind {
        case .mysql: sql = "SELECT VERSION()"
        case .postgres: sql = "SHOW server_version"
        case .sqlite: sql = "SELECT sqlite_version()"
        case .mongodb: return ""
        }
        let result = try await query(sql, database: nil)
        return result.rows.first?.first?.displayText ?? ""
    }
}
