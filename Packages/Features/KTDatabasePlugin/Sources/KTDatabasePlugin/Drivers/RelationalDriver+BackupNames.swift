import Foundation

public extension RelationalDriver {
    func backupDatabaseNames() async throws -> [String] {
        try await listDatabases().map(\.name)
    }
}
