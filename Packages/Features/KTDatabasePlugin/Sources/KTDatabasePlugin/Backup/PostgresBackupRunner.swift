import Foundation
import KTPlatformContracts
import KTStackCore

struct PostgresBackupRunner {
    let tools: any DatabaseToolsProviding
    private let versionProvider: @Sendable () -> String?

    init(
        tools: any DatabaseToolsProviding,
        activeVersion: (@Sendable () -> String?)? = nil
    ) {
        self.tools = tools
        if let activeVersion {
            self.versionProvider = activeVersion
        } else {
            self.versionProvider = { tools.activeVersion(.postgres) }
        }
    }

    static let requiredBinaries = ["bin/pg_dump", "bin/pg_restore", "bin/createdb", "bin/dropdb", "bin/psql"]

    var isAvailable: Bool {
        guard let version = versionProvider() else { return false }
        let fm = FileManager.default
        return Self.requiredBinaries.allSatisfy { relPath in
            guard let url = tools.binary(.postgres, relPath, version: version) else { return false }
            return fm.isExecutableFile(atPath: url.path)
        }
    }

    func binary(_ relPath: String) throws -> URL {
        guard let version = versionProvider(),
              let url = tools.binary(.postgres, relPath, version: version),
              FileManager.default.isExecutableFile(atPath: url.path)
        else {
            throw DatabaseError.engineNotInstalled(kind: "PostgreSQL")
        }
        return url
    }

    func installedVersion() -> String? {
        versionProvider()
    }

    func writePasswordFile(_ password: String?) throws -> URL? {
        guard let password, !password.isEmpty else { return nil }
        guard !password.contains(where: { $0 == ":" || $0 == "\n" || $0 == "\r" }) else {
            throw DatabaseError.connection("Password contains a character the PostgreSQL client config can't carry.")
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ktstack-pgpass-\(UUID().uuidString)")
        let created = FileManager.default.createFile(
            atPath: url.path,
            contents: Data("*:*:*:*:\(password)\n".utf8),
            attributes: [.posixPermissions: 0o600]
        )
        guard created else {
            throw DatabaseError.connection("Couldn't write the temporary PostgreSQL client config.")
        }
        return url
    }

    func connectionArgs(_ profile: ConnectionProfile) throws -> [String] {
        try DumpService.validateHost(profile.host)
        try DumpService.validateIdentifier(profile.user, label: "user", maxLength: 255)
        return ["-h", profile.host, "-p", String(profile.port), "-U", profile.user]
    }

    @discardableResult
    func run(_ executable: URL, args: [String], passwordFile: URL?) async throws -> String {
        var env = ["PATH": "/usr/bin:/bin:/usr/sbin:/sbin"]
        if let passwordFile { env["PGPASSFILE"] = passwordFile.path }
        let result: ProcessResult
        do {
            result = try await ProcessRunner().runAsync(
                ProcessRequest(executable: executable.path, arguments: args, environment: env)
            )
        } catch {
            throw DatabaseError.connection(
                "Couldn't launch \(executable.lastPathComponent): \(error.localizedDescription)"
            )
        }
        guard result.status == 0, result.interruption == nil else {
            let message = result.stderrText.trimmingCharacters(in: .whitespacesAndNewlines)
            throw Self.classify(message, tool: executable.lastPathComponent, status: result.status)
        }
        return result.stdoutText
    }

    private static func classify(_ stderr: String, tool: String, status: Int32) -> DatabaseError {
        let lower = stderr.lowercased()
        if lower.contains("permission denied") || lower.contains("must be owner") || lower.contains("must be superuser") {
            return .authenticationFailed(
                "The connection role lacks the privilege needed for this operation: \(stderr)"
            )
        }
        return .connection("\(tool) failed (exit \(status)): \(stderr)")
    }
}
