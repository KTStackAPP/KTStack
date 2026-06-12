import Foundation

/// Manages the per-version `php.ini` files under `config/php/<version>/`. Seeds a sane default on
/// first use, reads/writes atomically while keeping a `.bak` of the previous content, and can reset
/// a version back to the template or restore the last backup after a bad edit.
///
/// php-fpm is pointed at this file via `-c` (see `PHPFPMController`), so a save + pool reload is what
/// makes an edit take effect. A missing/unseeded file means php-fpm falls back to compiled defaults.
public struct PHPIniStore: Sendable {
    private let paths: AppSupportPaths
    private var fileManager: FileManager { .default }

    public init(paths: AppSupportPaths = AppSupportPaths()) {
        self.paths = paths
    }

    /// Create `config/php/<version>/php.ini` from the template if it does not yet exist. Idempotent —
    /// never clobbers an existing (possibly user-edited) file. Call before starting a pool so `-c`
    /// always points at a real file.
    public func ensureSeeded(version: String) throws {
        let url = paths.phpIni(version: version)
        guard !fileManager.fileExists(atPath: url.path) else { return }
        try fileManager.createDirectory(at: paths.phpIniDir(version: version),
                                        withIntermediateDirectories: true,
                                        attributes: [.posixPermissions: 0o700])
        try PHPIniTemplate.default.write(to: url, atomically: true, encoding: .utf8)
    }

    /// Current ini contents for a version, seeding the default first if absent (so the editor always
    /// opens something valid).
    public func read(version: String) throws -> String {
        try ensureSeeded(version: version)
        return try String(contentsOf: paths.phpIni(version: version), encoding: .utf8)
    }

    /// Overwrite the version's ini atomically, first copying the existing content to `php.ini.bak`
    /// so a bad edit can be reverted. Seeds the dir if this is the very first write.
    public func write(version: String, contents: String) throws {
        try fileManager.createDirectory(at: paths.phpIniDir(version: version),
                                        withIntermediateDirectories: true,
                                        attributes: [.posixPermissions: 0o700])
        let url = paths.phpIni(version: version)
        if fileManager.fileExists(atPath: url.path) {
            let bak = backupURL(version: version)
            try? fileManager.removeItem(at: bak)
            try? fileManager.copyItem(at: url, to: bak)
        }
        try contents.write(to: url, atomically: true, encoding: .utf8)
    }

    /// Rewrite the version's ini back to the seeded template (keeping a `.bak` of what was there).
    public func resetToDefault(version: String) throws {
        try write(version: version, contents: PHPIniTemplate.default)
    }

    /// Restore the last `.bak` over the live ini (used after a failed reload). No-op if no backup.
    @discardableResult
    public func restoreBackup(version: String) throws -> Bool {
        let bak = backupURL(version: version)
        guard fileManager.fileExists(atPath: bak.path) else { return false }
        let url = paths.phpIni(version: version)
        try? fileManager.removeItem(at: url)
        try fileManager.copyItem(at: bak, to: url)
        return true
    }

    /// Parse-check candidate ini content with the version's `php` CLI before it goes live. php is
    /// lenient — a syntactically broken ini exits 0 but prints `PHP:  syntax error …` to stderr — so
    /// we treat any stderr from `php -c <tmp> -v` as a warning to surface. Returns nil when the ini is
    /// clean OR when php isn't installed to check (can't validate → don't block the user). Blocking
    /// here keeps a malformed ini from ever reaching a live pool (which would only log, not crash, but
    /// is still wrong); the safe degradation mirrors the `-c`-only-if-exists rule.
    public func validate(version: String, contents: String) -> String? {
        let php = paths.phpBinary(version: version)
        guard fileManager.isExecutableFile(atPath: php.path) else { return nil }
        let tmp = fileManager.temporaryDirectory
            .appendingPathComponent("kdwarm-ini-check-\(UUID().uuidString).ini")
        guard (try? contents.write(to: tmp, atomically: true, encoding: .utf8)) != nil else { return nil }
        defer { try? fileManager.removeItem(at: tmp) }

        let proc = Process()
        proc.executableURL = php
        proc.arguments = ["-c", tmp.path, "-v"]
        let errPipe = Pipe()
        proc.standardError = errPipe
        proc.standardOutput = Pipe()
        do { try proc.run() } catch { return nil }
        let data = errPipe.fileHandleForReading.readDataToEndOfFile()
        proc.waitUntilExit()
        let msg = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (msg?.isEmpty == false) ? msg : nil
    }

    private func backupURL(version: String) -> URL {
        paths.phpIni(version: version).appendingPathExtension("bak")
    }
}
