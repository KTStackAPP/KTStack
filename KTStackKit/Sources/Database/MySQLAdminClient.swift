import Foundation
import KTPlatformContracts
import KTStackCore

/// Admin operations against the managed MySQL engine via the `mysql` CLI, for Sites install/restore.
/// Platform-side so KTStackKit needs no NIO driver. Only the managed engine: root, no password. The
/// client resolves from the managed runtime first, then PATH. Security: identifier allowlist +
/// backtick quoting before any name reaches SQL; credentials only through a 0600 defaults file.
public struct MySQLAdminClient: Sendable {
    public enum ClientError: LocalizedError, Equatable {
        case clientNotInstalled
        case invalidIdentifier(String)
        case failed(String)

        public var errorDescription: String? {
            switch self {
            case .clientNotInstalled: "The MySQL client (bin/mysql) isn't installed."
            case let .invalidIdentifier(name): "Invalid database name: \(name)"
            case let .failed(message): message
            }
        }
    }

    private let paths: AppSupportPaths
    private let host: String
    private let port: Int
    private let systemToolSearchPaths: [URL]

    public init(
        paths: AppSupportPaths = AppSupportPaths(),
        host: String = "127.0.0.1",
        port: Int = 3306,
        systemToolSearchPaths: [URL] = MySQLAdminClient.defaultSystemToolSearchPaths()
    ) {
        self.paths = paths
        self.host = host
        self.port = port
        self.systemToolSearchPaths = systemToolSearchPaths
    }

    public static func defaultSystemToolSearchPaths() -> [URL] {
        var dirs = ["/opt/homebrew/bin", "/usr/local/bin", "/usr/bin"]
        if let path = ProcessInfo.processInfo.environment["PATH"] {
            dirs += path.split(separator: ":").map(String.init)
        }
        var seen = Set<String>()
        return dirs.filter { seen.insert($0).inserted }
            .map { URL(fileURLWithPath: $0, isDirectory: true) }
    }

    public func databaseExists(_ name: String) async throws -> Bool {
        try Self.validateIdentifier(name)
        let mysql = try resolveClient()
        let defaults = try writeDefaultsFile()
        defer { try? FileManager.default.removeItem(at: defaults) }
        let output = try await runCapturing(
            mysql, args: ["--defaults-extra-file=\(defaults.path)", "-N", "-B", "-e", "SHOW DATABASES"]
        )
        return output.split(separator: "\n").contains { $0.trimmingCharacters(in: .whitespaces) == name }
    }

    public func createDatabase(_ name: String) async throws {
        try Self.validateIdentifier(name)
        let mysql = try resolveClient()
        let defaults = try writeDefaultsFile()
        defer { try? FileManager.default.removeItem(at: defaults) }
        try await run(
            mysql,
            args: ["--defaults-extra-file=\(defaults.path)", "-e", "CREATE DATABASE \(Self.quoteIdent(name))"],
            stdin: nil
        )
    }

    public func dropDatabase(_ name: String) async throws {
        try Self.validateIdentifier(name)
        let mysql = try resolveClient()
        let defaults = try writeDefaultsFile()
        defer { try? FileManager.default.removeItem(at: defaults) }
        try await run(
            mysql,
            args: ["--defaults-extra-file=\(defaults.path)", "-e", "DROP DATABASE IF EXISTS \(Self.quoteIdent(name))"],
            stdin: nil
        )
    }

    public func importDump(database: String, from input: URL) async throws {
        try Self.validateIdentifier(database)
        let mysql = try resolveClient()
        guard FileManager.default.fileExists(atPath: input.path) else {
            throw ClientError.failed("Dump file not found: \(input.lastPathComponent)")
        }
        let defaults = try writeDefaultsFile()
        defer { try? FileManager.default.removeItem(at: defaults) }

        try await run(
            mysql,
            args: [
                "--defaults-extra-file=\(defaults.path)",
                "-e",
                "CREATE DATABASE IF NOT EXISTS \(Self.quoteIdent(database))",
            ],
            stdin: nil
        )

        guard let inHandle = try? FileHandle(forReadingFrom: input) else {
            throw ClientError.failed("Couldn't open the dump file for reading.")
        }
        defer { try? inHandle.close() }
        try await run(
            mysql,
            args: ["--defaults-extra-file=\(defaults.path)", "--", database],
            stdin: inHandle
        )
    }

    static func validateIdentifier(_ value: String, maxLength: Int = 64) throws {
        guard !value.isEmpty else { throw ClientError.invalidIdentifier("(empty)") }
        guard value.count <= maxLength else { throw ClientError.invalidIdentifier(value) }
        guard !value.hasPrefix("-") else { throw ClientError.invalidIdentifier(value) }
        let illegal = Set("=/\\`'\"".unicodeScalars)
        for scalar in value.unicodeScalars where scalar.value < 0x20 || illegal.contains(scalar) {
            throw ClientError.invalidIdentifier(value)
        }
    }

    static func quoteIdent(_ name: String) -> String {
        "`" + name.replacingOccurrences(of: "`", with: "``") + "`"
    }

    private func resolveClient() throws -> URL {
        let fm = FileManager.default
        if let managed = DatabaseToolsService(paths: paths).binary(.mysql, "bin/mysql"),
           fm.isExecutableFile(atPath: managed.path)
        {
            return managed
        }
        for dir in systemToolSearchPaths {
            let candidate = dir.appendingPathComponent("mysql")
            if fm.isExecutableFile(atPath: candidate.path) { return candidate }
        }
        throw ClientError.clientNotInstalled
    }

    func writeDefaultsFile() throws -> URL {
        let content = "[client]\nuser=root\nhost=\(host)\nport=\(port)\nssl-mode=PREFERRED\n"
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ktstack-mysqladmin-\(UUID().uuidString).cnf")
        let created = FileManager.default.createFile(
            atPath: url.path,
            contents: Data(content.utf8),
            attributes: [.posixPermissions: 0o600]
        )
        guard created else {
            throw ClientError.failed("Couldn't write the temporary database client config.")
        }
        return url
    }

    private func run(_ executable: URL, args: [String], stdin: FileHandle?) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            DispatchQueue.global(qos: .userInitiated).async {
                let proc = Process()
                proc.executableURL = executable
                proc.arguments = args
                proc.environment = ["PATH": "/usr/bin:/bin:/usr/sbin:/sbin"]
                let errPipe = Pipe()
                proc.standardError = errPipe
                proc.standardInput = stdin ?? FileHandle.nullDevice
                proc.standardOutput = FileHandle.nullDevice
                do {
                    try proc.run()
                } catch {
                    cont.resume(throwing: ClientError.failed(
                        "Couldn't launch \(executable.lastPathComponent): \(error.localizedDescription)"
                    ))
                    return
                }
                let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
                proc.waitUntilExit()
                if proc.terminationStatus == 0 {
                    cont.resume()
                } else {
                    let message = String(data: errData, encoding: .utf8)?
                        .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    cont.resume(throwing: ClientError.failed(
                        "\(executable.lastPathComponent) failed (exit \(proc.terminationStatus)): \(message)"
                    ))
                }
            }
        }
    }

    private func runCapturing(_ executable: URL, args: [String]) async throws -> String {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<String, Error>) in
            DispatchQueue.global(qos: .userInitiated).async {
                let proc = Process()
                proc.executableURL = executable
                proc.arguments = args
                proc.environment = ["PATH": "/usr/bin:/bin:/usr/sbin:/sbin"]
                let outPipe = Pipe()
                let errPipe = Pipe()
                proc.standardOutput = outPipe
                proc.standardError = errPipe
                proc.standardInput = FileHandle.nullDevice
                do {
                    try proc.run()
                } catch {
                    cont.resume(throwing: ClientError.failed(
                        "Couldn't launch \(executable.lastPathComponent): \(error.localizedDescription)"
                    ))
                    return
                }
                let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
                let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
                proc.waitUntilExit()
                if proc.terminationStatus == 0 {
                    cont.resume(returning: String(data: outData, encoding: .utf8) ?? "")
                } else {
                    let message = String(data: errData, encoding: .utf8)?
                        .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    cont.resume(throwing: ClientError.failed(
                        "\(executable.lastPathComponent) failed (exit \(proc.terminationStatus)): \(message)"
                    ))
                }
            }
        }
    }
}
