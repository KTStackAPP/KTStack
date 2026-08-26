import Foundation
import KTPlatformContracts

public protocol SiteInstaller: Sendable {
    func scaffold(
        into folder: URL,
        request: NewSiteRequest,
        emit: @Sendable (String) -> Void
    ) async throws
}

public final class SiteInstallService: Sendable {
    private let database: DatabaseProvisioner
    public init(database: DatabaseProvisioner) {
        self.database = database
    }

    public func install(
        _ request: NewSiteRequest,
        installer: SiteInstaller,
        register: @Sendable (URL) async throws -> Site,
        emit: @Sendable @escaping (InstallEvent) -> Void
    ) async throws -> Site {
        let fm = FileManager.default
        var createdDatabase: String?
        var createdFolder = false

        func rollback() async {
            if let db = createdDatabase { try? await database.dropDatabase(db) }
            if createdFolder { try? fm.removeItem(at: request.folder) }
        }

        do {
            emit(InstallEvent(phase: .preparing, message: "Preparing \(request.name)…"))
            guard !fm.fileExists(atPath: request.folder.path) else {
                throw InstallError.folderExists(request.folder.lastPathComponent)
            }
            try fm.createDirectory(at: request.folder, withIntermediateDirectories: true)
            createdFolder = true

            if let db = request.databaseName {
                try Task.checkCancellation()
                emit(InstallEvent(phase: .configuringDatabase, message: "Creating database \(db)…"))
                try await database.createDatabase(db)
                createdDatabase = db
            }

            try Task.checkCancellation()
            emit(InstallEvent(phase: .scaffolding, message: "Installing \(request.kind.label)…"))
            try await installer.scaffold(into: request.folder, request: request) { line in
                emit(InstallEvent(phase: .scaffolding, message: line))
            }

            try Task.checkCancellation()
            emit(InstallEvent(phase: .finalizing, message: "Registering site…"))
            let site = try await register(request.folder)
            emit(InstallEvent(phase: .done, message: "Site ready at https://\(request.domain)"))
            return site
        } catch {
            await rollback()
            throw error
        }
    }
}
