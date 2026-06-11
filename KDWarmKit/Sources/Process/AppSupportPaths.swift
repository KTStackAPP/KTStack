import Foundation

/// Canonical filesystem layout under `~/Library/Application Support/KDWarm`.
///
/// Single source of truth for every directory the runtime touches (bin, config, run,
/// logs, sites). Established here in the first HTTP slice and reused by all later phases.
/// The signed app bundle is immutable, so binaries are staged into this writable tree and
/// run from here — never from inside `KDWarm.app`.
public struct AppSupportPaths: Sendable {
    public let root: URL

    /// Default location: the user's Application Support directory + `KDWarm`.
    public init(fileManager: FileManager = .default) {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        self.root = base.appendingPathComponent("KDWarm", isDirectory: true)
    }

    /// Explicit root — used by tests to stage the tree in a temp dir.
    public init(root: URL) { self.root = root }

    // MARK: Directories

    public var bin: URL              { dir("bin") }
    public var runtimes: URL         { dir("runtimes") }          // Phase 7
    public var config: URL           { dir("config") }
    public var nginxConfigDir: URL   { config.appendingPathComponent("nginx", isDirectory: true) }
    public var sitesEnabled: URL     { nginxConfigDir.appendingPathComponent("sites-enabled", isDirectory: true) }
    public var phpFpmConfigDir: URL  { config.appendingPathComponent("php-fpm", isDirectory: true) }
    public var run: URL              { dir("run") }
    public var logs: URL             { dir("logs") }
    public var sites: URL            { dir("sites") }

    /// Every directory that `ensureDirectoryTree()` creates.
    public var allDirectories: [URL] {
        [root, bin, runtimes, config, nginxConfigDir, sitesEnabled, phpFpmConfigDir, run, logs, sites]
    }

    // MARK: Binaries (staged copies)

    public var nginxBinary: URL  { bin.appendingPathComponent("nginx") }
    public var phpBinary: URL    { bin.appendingPathComponent("php") }
    public var phpFpmBinary: URL { bin.appendingPathComponent("php-fpm") }

    // MARK: Well-known files

    public var nginxConf: URL    { nginxConfigDir.appendingPathComponent("nginx.conf") }
    public var nginxPid: URL     { run.appendingPathComponent("nginx.pid") }
    public var nginxErrorLog: URL  { logs.appendingPathComponent("nginx-error.log") }
    public var nginxAccessLog: URL { logs.appendingPathComponent("nginx-access.log") }

    public func vhost(_ name: String) -> URL {
        sitesEnabled.appendingPathComponent("\(name).conf")
    }
    public func phpFpmPool(_ name: String) -> URL {
        phpFpmConfigDir.appendingPathComponent("\(name).conf")
    }
    public func phpFpmSocket(_ name: String) -> URL {
        run.appendingPathComponent("php-fpm-\(name).sock")
    }
    public func phpFpmPid(_ name: String) -> URL {
        run.appendingPathComponent("php-fpm-\(name).pid")
    }
    public func phpFpmLog(_ name: String) -> URL {
        logs.appendingPathComponent("php-fpm-\(name).log")
    }

    private func dir(_ name: String) -> URL {
        root.appendingPathComponent(name, isDirectory: true)
    }

    /// Create the full tree on first run, restricting each dir to the owning user (0700)
    /// so no other local account can drop a tampered binary or read site state.
    public func ensureDirectoryTree(fileManager: FileManager = .default) throws {
        for url in allDirectories {
            try fileManager.createDirectory(
                at: url,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700])
        }
    }
}
