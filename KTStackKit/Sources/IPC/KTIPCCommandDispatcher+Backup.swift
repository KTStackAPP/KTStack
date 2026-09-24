import Foundation
import KTPlatformContracts
import KTStackCore

extension KTIPCCommandDispatcher {
    func handleDatabaseBackup(request: KTIPCRequest) async -> KTIPCResponse {
        guard let database = request.params?["database"]?.trimmingCharacters(in: .whitespaces), !database.isEmpty else {
            return .fail("Missing 'database' parameter", id: request.id)
        }
        var engine: DatabaseEngine?
        if let raw = request.params?["engine"], !raw.isEmpty {
            guard let parsed = DatabaseEngine(rawValue: raw.lowercased()) else {
                let valid = DatabaseEngine.allCases.map(\.rawValue).joined(separator: ", ")
                return .fail("Unknown engine '\(raw)'. Valid: \(valid)", id: request.id)
            }
            engine = parsed
        }
        guard let provider = await backupProvider() else {
            return .fail(Self.backupUnavailable, id: request.id)
        }
        do {
            let artifact = try await provider.backup(database: database, engine: engine)
            guard artifact.hasContent else {
                return .fail("Backup of \(database) produced no file.", id: request.id)
            }
            return .ok(artifact.fileURL.path, id: request.id)
        } catch {
            return .fail("Backup of \(database) failed: \(error.localizedDescription)", id: request.id)
        }
    }
}
