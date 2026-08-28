import Foundation
import MySQLNIO
import NIOCore

public extension MySQLDriver {
    // Một transaction cho cả batch: mỗi step phải đúng expectedAffected, lệch một step là rollback tất cả.
    func executeTransaction(_ steps: [WriteStep], database: String) async throws {
        guard !steps.isEmpty else { return }
        try preflightManagedEngine()
        let connection = try await connect(database: database)
        do {
            _ = try await connection.simpleQuery("START TRANSACTION").get()
            for step in steps {
                try await run(step, on: connection)
            }
            _ = try await connection.simpleQuery("COMMIT").get()
            try await connection.close().get()
        } catch let error as DatabaseError {
            _ = try? await connection.simpleQuery("ROLLBACK").get()
            try? await connection.close().get()
            throw error
        } catch {
            _ = try? await connection.simpleQuery("ROLLBACK").get()
            try? await connection.close().get()
            throw MySQLErrorMapper.map(error, isManaged: profile.isManaged)
        }
    }

    private func run(_ step: WriteStep, on connection: MySQLConnection) async throws {
        let affected = AffectedRowsBox()
        _ = try await connection.query(
            step.statement.sql,
            step.statement.binds.map(MySQLCellMapper.mysqlData(for:)),
            onMetadata: { affected.value = $0.affectedRows }
        ).get()

        if affected.value == UInt64(step.expectedAffected) { return }

        // UPDATE chạm 0 hàng: no-op (giá trị không đổi) nếu key vẫn tồn tại, ngược lại là stale.
        if affected.value == 0, let check = step.noOpKeyCheck {
            let rows = try await connection.query(
                check.sql,
                check.binds.map(MySQLCellMapper.mysqlData(for:))
            ).get()
            if !rows.isEmpty { return }
        }
        throw DatabaseError.writeConflict("A staged change no longer matches; the batch was rolled back.")
    }
}
