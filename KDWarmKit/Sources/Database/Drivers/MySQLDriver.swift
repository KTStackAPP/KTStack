import Foundation
import MySQLNIO
import NIOCore
import NIOPosix
import NIOSSL


public struct MySQLDriver: RelationalDriver {
    public let kind: DatabaseKind = .mysql


    let profile: ConnectionProfile
    let password: String?
    let catalog: ServiceBinaryCatalog
    let dialect = SQLDialect.forKind(.mysql)

    public init(profile: ConnectionProfile,
                password: String?,
                catalog: ServiceBinaryCatalog = ServiceBinaryCatalog(paths: AppSupportPaths())) {
        self.profile = profile
        self.password = password
        self.catalog = catalog
    }

    // MARK: - RelationalDriver

    public func ping() async throws {
        _ = try await runStatement("SELECT 1")
    }

    public func listDatabases() async throws -> [DatabaseInfo] {
        let result = try await runStatement(
            "SELECT SCHEMA_NAME FROM information_schema.SCHEMATA ORDER BY SCHEMA_NAME")
        return result.rows.compactMap { $0.first?.displayText }.map(DatabaseInfo.init(name:))
    }

    public func listTables(database: String) async throws -> [TableInfo] {
        
        let sql = """
        SELECT TABLE_NAME, TABLE_TYPE FROM information_schema.TABLES \
        WHERE TABLE_SCHEMA = \(try MySQLErrorMapper.quoteLiteral(database)) ORDER BY TABLE_NAME
        """
        let result = try await runStatement(sql)
        return result.rows.compactMap { row in
            guard let name = row.first?.displayText else { return nil }
            let isView = row.count > 1 && (row[1].displayText == "VIEW")
            return TableInfo(name: name, isView: isView)
        }
    }

    public func columns(database: String, table: String) async throws -> [ColumnInfo] {
       
        let sql = """
        SELECT COLUMN_NAME, COLUMN_TYPE, IS_NULLABLE, COLUMN_KEY, COLUMN_DEFAULT \
        FROM information_schema.COLUMNS \
        WHERE TABLE_SCHEMA = \(try MySQLErrorMapper.quoteLiteral(database)) \
        AND TABLE_NAME = \(try MySQLErrorMapper.quoteLiteral(table)) \
        ORDER BY ORDINAL_POSITION
        """
        let result = try await runStatement(sql)
        return result.rows.compactMap { row in
            guard row.count >= 4, let name = row[0].displayText else { return nil }
            return ColumnInfo(
                name: name,
                dataType: row[1].displayText ?? "",
                isNullable: row[2].displayText == "YES",
                isPrimaryKey: row[3].displayText == "PRI",
                defaultValue: row[4].displayText)
        }
    }

    public func query(_ sql: String, database: String?) async throws -> QueryResult {
        try await runStatement(sql, database: database)
    }

    public func paginatedRows(database: String, table: String,
                              limit: Int, offset: Int) async throws -> QueryResult {
        let qualified = try dialect.qualifiedTable(schema: database, table: table)
        let sql = dialect.paginate("SELECT * FROM \(qualified)", limit: limit, offset: offset)
        return try await runStatement(sql, database: database)
    }

    // MARK: - Connect + run

    private func runStatement(_ sql: String, database: String? = nil) async throws -> QueryResult {
        try preflightManagedEngine()
        let connection = try await connect(database: database)
        let command = MySQLTextQueryCommand(sql: sql)
        do {
            try await connection.send(command, logger: connection.logger).get()
        } catch {
            try? await connection.close().get()
            throw MySQLErrorMapper.map(error, isManaged: profile.isManaged)
        }
        try await connection.close().get()
        let columns = command.columns.map(MySQLCellMapper.columnMeta)
        let rows = command.rows.map { row in
            zip(row.columnDefinitions, row.values).map { MySQLCellMapper.cell(for: $0, value: $1) }
        }
        return QueryResult(columns: columns, rows: rows)
    }

    func connect(database: String?) async throws -> MySQLConnection {
        let group = try EventLoopProvider.shared.group()
        let address = try SocketAddress.makeAddressResolvingHost(profile.host, port: profile.port)
        let connection: MySQLConnection
        do {
            connection = try await MySQLConnection.connect(
                to: address,
                username: profile.user,
                database: database ?? profile.database,
                password: password,
                tlsConfiguration: tlsConfiguration(),
                on: group.next()
            ).get()
        } catch {
            throw MySQLErrorMapper.map(error, isManaged: profile.isManaged)
        }
        
        if profile.readOnly {
            do {
                _ = try await connection.simpleQuery("SET SESSION TRANSACTION READ ONLY").get()
            } catch {
                try? await connection.close().get()
                throw MySQLErrorMapper.map(error, isManaged: profile.isManaged)
            }
        }
        return connection
    }


    func preflightManagedEngine() throws {
        guard profile.isManaged else { return }
        guard catalog.isInstalled(.mysql) else {
            throw DatabaseError.engineNotInstalled(kind: "MySQL")
        }
    }

    
    private func tlsConfiguration() -> TLSConfiguration? {
        var config = TLSConfiguration.makeClientConfiguration()
        switch profile.tlsMode {
        case .disable:
            return nil
        case .prefer:
            config.certificateVerification = .none
        case .require:
            config.certificateVerification = .noHostnameVerification
        case .verifyFull:
            config.certificateVerification = .fullVerification
        }
        return config
    }
}
