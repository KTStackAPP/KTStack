import Foundation
import PostgresNIO

public extension PostgresDriver {
    func executeTransaction(_ steps: [WriteStep], database: String) async throws {
        guard !steps.isEmpty else { return }
        try preflightManagedEngine()
        let connection = try await connect()
        do {
            _ = try await connection.query("BEGIN", logger: logger)
            for step in steps {
                try await run(step, on: connection)
            }
            _ = try await connection.query("COMMIT", logger: logger)
            try await connection.close()
        } catch let error as DatabaseError {
            _ = try? await connection.query("ROLLBACK", logger: logger)
            try? await connection.close()
            throw error
        } catch {
            _ = try? await connection.query("ROLLBACK", logger: logger)
            try? await connection.close()
            throw PostgresErrorMapper.map(error, isManaged: profile.isManaged)
        }
    }

    private func run(_ step: WriteStep, on connection: PostgresConnection) async throws {
        let sql = step.statement.sql.trimmingCharacters(in: .whitespacesAndNewlines)
        let isReturningCandidate = sql.uppercased().hasPrefix("INSERT")
            || sql.uppercased().hasPrefix("UPDATE")
            || sql.uppercased().hasPrefix("DELETE")
        let finalSQL = isReturningCandidate ? "\(sql) RETURNING 1" : sql
        let query = PostgresQuery(
            unsafeSQL: finalSQL,
            binds: PostgresCellMapper.bindings(step.statement.binds)
        )
        let affected = try await connection.query(query, logger: logger).collect().count
        if affected == step.expectedAffected { return }

        if affected == 0, let check = step.noOpKeyCheck {
            let checkQuery = PostgresQuery(
                unsafeSQL: check.sql,
                binds: PostgresCellMapper.bindings(check.binds)
            )
            let checkRows = try await connection.query(checkQuery, logger: logger).collect()
            if !checkRows.isEmpty { return }
        }
        throw DatabaseError.writeConflict("A staged change no longer matches; the batch was rolled back.")
    }
}
