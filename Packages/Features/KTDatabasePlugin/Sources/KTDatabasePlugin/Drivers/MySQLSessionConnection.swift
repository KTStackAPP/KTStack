import Foundation
import MySQLNIO
import NIOCore

final class MySQLSessionConnection: SessionConnection, @unchecked Sendable {
    private let connection: MySQLConnection
    private let isManaged: Bool
    private let threadID: Int
    private let makeControl: @Sendable () async throws -> MySQLConnection

    init(
        connection: MySQLConnection,
        isManaged: Bool,
        threadID: Int,
        makeControl: @escaping @Sendable () async throws -> MySQLConnection
    ) {
        self.connection = connection
        self.isManaged = isManaged
        self.threadID = threadID
        self.makeControl = makeControl
    }

    var isLive: Bool {
        !connection.isClosed
    }

    func useDatabase(_ database: String) async throws {
        let quoted = try SQLDialect.forKind(.mysql).quoteIdent(database)
        do {
            _ = try await connection.simpleQuery("USE \(quoted)").get()
        } catch {
            throw MySQLErrorMapper.map(error, isManaged: isManaged)
        }
    }

    func runText(_ sql: String) async throws -> QueryResult {
        let command = MySQLTextQueryCommand(sql: sql)
        do {
            try await connection.send(command, logger: connection.logger).get()
        } catch {
            throw MySQLErrorMapper.map(error, isManaged: isManaged)
        }
        let columns = command.columns.map(MySQLCellMapper.columnMeta)
        let rows = command.rows.map { row in
            zip(row.columnDefinitions, row.values).map { MySQLCellMapper.cell(for: $0, value: $1) }
        }
        return QueryResult(columns: columns, rows: rows)
    }

    func runSelect(_ statement: DMLStatement) async throws -> QueryResult {
        let binds = statement.binds.map(MySQLCellMapper.mysqlData(for:))
        do {
            let rows = try await connection.query(statement.sql, binds).get()
            return MySQLCellMapper.result(from: rows)
        } catch {
            throw MySQLErrorMapper.map(error, isManaged: isManaged)
        }
    }

    // Dừng query đang chạy trên server qua control connection; session vẫn sống để tái dùng.
    func cancel() async {
        guard threadID > 0, let control = try? await makeControl() else { return }
        _ = try? await control.simpleQuery("KILL QUERY \(threadID)").get()
        try? await control.close().get()
    }

    func shutdown() async {
        try? await connection.close().get()
    }
}
