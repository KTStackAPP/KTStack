import Foundation
import GRDB

public extension SQLiteDriver {
    func executeTransaction(_ steps: [WriteStep], database: String) async throws {
        guard !steps.isEmpty else { return }
        let queue = try makeQueue()
        do {
            try await queue.write { db in
                for step in steps {
                    try run(step, on: db)
                }
            }
        } catch {
            throw Self.mapError(error)
        }
    }

    private func run(_ step: WriteStep, on db: Database) throws {
        try db.execute(
            sql: step.statement.sql,
            arguments: SQLiteCellMapper.arguments(step.statement.binds)
        )
        let affected = db.changesCount
        if affected == step.expectedAffected { return }

        if affected == 0, let check = step.noOpKeyCheck {
            let rows = try Row.fetchAll(
                db,
                sql: check.sql,
                arguments: SQLiteCellMapper.arguments(check.binds)
            )
            if !rows.isEmpty { return }
        }
        throw DatabaseError.writeConflict("A staged change no longer matches; the batch was rolled back.")
    }
}
