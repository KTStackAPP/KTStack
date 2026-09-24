import Foundation
import PostgresNIO

public extension PostgresDriver {
    func backupDatabaseNames() async throws -> [String] {
        let result = try await runQuery(PostgresQuery(
            unsafeSQL: "SELECT datname FROM pg_database WHERE datallowconn AND NOT datistemplate ORDER BY datname"
        ))
        return result.rows.compactMap { $0.first?.displayText }
    }
}
