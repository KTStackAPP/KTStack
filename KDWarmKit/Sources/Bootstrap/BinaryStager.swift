import Foundation

/// Copies the bundled, relocatable binaries (nginx, php, php-fpm) out of the immutable
/// signed app bundle into the writable app-support `bin/` directory on first run, and
/// re-stages them when the bundle ships newer copies.
///
/// The signed `.app` is read-only, so the runtime CANNOT execute binaries in place — they
/// must live in a writable tree. Every binary's code signature is verified BEFORE it is
/// copied and AFTER it lands, as a defence against a tampered app-support directory: an
/// attacker who swapped `php-fpm` for a trojan would fail the post-stage `codesign` check
/// and the launch is aborted.
public struct BinaryStager {
    public enum StageError: LocalizedError {
        case missingSource(String)
        case signatureInvalid(String)
        case copyFailed(String, String)

        public var errorDescription: String? {
            switch self {
            case .missingSource(let p):   return "Bundled binary not found: \(p)"
            case .signatureInvalid(let p): return "Code signature check failed for \(p) — refusing to run a possibly tampered binary."
            case .copyFailed(let n, let m): return "Could not stage \(n): \(m)"
            }
        }
    }

    /// The binaries this phase REQUIRES — a missing one aborts startup.
    /// `dnsmasq` is bundled for DNS automation; the sudo-fallback / helper copies it to a
    /// root-owned location, but it is staged into user app-support too for signature verification.
    public static let binaryNames = ["nginx", "php", "php-fpm", "dnsmasq", "mkcert"]

    /// Database / Mailpit binaries staged ONLY when present in the bundle. They are large relocatable
    /// builds produced by a separate pipeline; until a build ships them the matching service reports
    /// "Not installed" rather than failing. `initdb` accompanies `postgres`.
    public static let optionalBinaryNames = ["mysqld", "postgres", "initdb", "redis-server", "mailpit"]

    private let bundleBinDir: URL
    private let paths: AppSupportPaths
    private let fileManager: FileManager

    public init(bundleBinDir: URL, paths: AppSupportPaths, fileManager: FileManager = .default) {
        self.bundleBinDir = bundleBinDir
        self.paths = paths
        self.fileManager = fileManager
    }

    /// Stage any binary that is missing or out of date. Verifies signatures on both ends.
    /// Required binaries must be present; optional DB/Mailpit binaries are staged only if bundled.
    public func stageIfNeeded() throws {
        try paths.ensureDirectoryTree(fileManager: fileManager)
        for name in Self.binaryNames {
            try stage(name)
        }
        for name in Self.optionalBinaryNames where fileManager.isReadableFile(
            atPath: bundleBinDir.appendingPathComponent(name).path) {
            try stage(name)
        }
    }

    private func stage(_ name: String) throws {
        let source = bundleBinDir.appendingPathComponent(name)
        let dest = paths.bin.appendingPathComponent(name)

        guard fileManager.isReadableFile(atPath: source.path) else {
            throw StageError.missingSource(source.path)
        }
        guard Self.verifySignature(at: source) else {
            throw StageError.signatureInvalid(source.path)
        }

        if try shouldRestage(source: source, dest: dest) {
            do {
                if fileManager.fileExists(atPath: dest.path) {
                    try fileManager.removeItem(at: dest)
                }
                try fileManager.copyItem(at: source, to: dest)
                try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: dest.path)
            } catch {
                throw StageError.copyFailed(name, error.localizedDescription)
            }
        }

        guard Self.verifySignature(at: dest) else {
            throw StageError.signatureInvalid(dest.path)
        }
    }

    /// Re-stage when the destination is absent or differs from the bundle copy (size or mtime).
    private func shouldRestage(source: URL, dest: URL) throws -> Bool {
        guard fileManager.fileExists(atPath: dest.path) else { return true }
        let s = try fileManager.attributesOfItem(atPath: source.path)
        let d = try fileManager.attributesOfItem(atPath: dest.path)
        let sSize = (s[.size] as? Int) ?? -1
        let dSize = (d[.size] as? Int) ?? -2
        if sSize != dSize { return true }
        let sDate = (s[.modificationDate] as? Date) ?? .distantFuture
        let dDate = (d[.modificationDate] as? Date) ?? .distantPast
        return sDate > dDate
    }

    /// `codesign --verify --strict`. Ad-hoc signatures (dev builds) pass and still seal the
    /// code, so post-stage tampering is detected.
    static func verifySignature(at url: URL) -> Bool {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        proc.arguments = ["--verify", "--strict", url.path]
        proc.standardOutput = FileHandle.nullDevice
        proc.standardError = FileHandle.nullDevice
        do { try proc.run() } catch { return false }
        proc.waitUntilExit()
        return proc.terminationStatus == 0
    }
}
