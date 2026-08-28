import Foundation
import MySQLNIO
import NIOCore

public extension MySQLDriver {
    func insert(database: String, table: String, values: [ColumnValue]) async throws {
        let statement = try dialect.insert(schema: database, table: table, values: values)
        try await executeWrite(statement, database: database, noOpKeyCheck: nil)
    }

    func update(
        database: String,
        table: String,
        values: [ColumnValue],
        key: [ColumnValue]
    ) async throws {
        let statement = try dialect.update(schema: database, table: table, values: values, key: key)
        // UPDATE affected==0 mơ hồ: no-op (giá trị không đổi) vs stale (không match hàng nào).
        let keyCheck = try dialect.selectKeyExists(schema: database, table: table, key: key)
        try await executeWrite(statement, database: database, noOpKeyCheck: keyCheck)
    }

    func delete(database: String, table: String, key: [ColumnValue]) async throws {
        let statement = try dialect.delete(schema: database, table: table, key: key)
        try await executeWrite(statement, database: database, noOpKeyCheck: nil)
    }

    private func executeWrite(
        _ statement: DMLStatement,
        database: String,
        noOpKeyCheck: DMLStatement?
    ) async throws {
        try preflightManagedEngine()
        let connection = try await connect(database: database)
        do {
            _ = try await connection.simpleQuery("START TRANSACTION").get()
            let affected = AffectedRowsBox()
            let binds = statement.binds.map(MySQLCellMapper.mysqlData(for:))
            _ = try await connection.query(
                statement.sql,
                binds,
                onMetadata: { affected.value = $0.affectedRows }
            ).get()

            if affected.value == 1 {
                _ = try await connection.simpleQuery("COMMIT").get()
                try await connection.close().get()
                return
            }

            if affected.value == 0, let noOpKeyCheck {
                let rows = try await connection.query(
                    noOpKeyCheck.sql,
                    noOpKeyCheck.binds.map(MySQLCellMapper.mysqlData(for:))
                ).get()
                if !rows.isEmpty {
                    // Hàng vẫn tồn tại, giá trị không đổi: no-op hợp lệ.
                    _ = try await connection.simpleQuery("COMMIT").get()
                    try await connection.close().get()
                    return
                }
                _ = try? await connection.simpleQuery("ROLLBACK").get()
                try? await connection.close().get()
                throw DatabaseError.writeConflict("The row no longer matches; it was changed or removed.")
            }

            _ = try? await connection.simpleQuery("ROLLBACK").get()
            try? await connection.close().get()
            if affected.value == 0 {
                throw DatabaseError.writeConflict("The row no longer matches; it was changed or removed.")
            }
            throw DatabaseError.connection(
                "Affected \(affected.value) rows; rolled back (expected exactly 1)."
            )
        } catch let error as DatabaseError {
            throw error // already mapped + connection handled above
        } catch {
            _ = try? await connection.simpleQuery("ROLLBACK").get()
            try? await connection.close().get()
            throw MySQLErrorMapper.map(error, isManaged: profile.isManaged)
        }
    }
}

private final class AffectedRowsBox: @unchecked Sendable {
    var value: UInt64 = 0
}
