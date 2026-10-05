import Foundation

public struct SettingsSnapshotWriter: Sendable {
    public static let folderName = "settings"
    public static let formatVersion = 1
    static let preferencesFile = "preferences.plist"
    static let infoFile = "snapshot.json"
    static let secretKeyMarkers = ["token", "secret", "password", "passwd", "credential", "apikey", "privatekey"]
    static let includedPaths = [
        "config/sites/sites.json",
        "config/nginx/site-directives",
        "config/nginx/nginx-extra.conf",
        "config/php",
        "config/shell-tools.json",
        "scheduled-backups/plans.json",
        "scheduled-backups/destinations.json"
    ]

    struct Info: Codable, Equatable {
        var version: Int
        var createdAt: Date
        var files: [String]
    }

    public let appSupportRoot: URL
    public let defaultsDomain: String?
    let now: @Sendable () -> Date

    public init(appSupportRoot: URL, defaultsDomain: String?, now: @escaping @Sendable () -> Date = { Date() }) {
        self.appSupportRoot = appSupportRoot
        self.defaultsDomain = defaultsDomain
        self.now = now
    }

    public func write(into directory: URL) throws {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        var files: [String] = []
        for path in Self.includedPaths {
            let source = appSupportRoot.appendingPathComponent(path)
            guard fileManager.fileExists(atPath: source.path) else { continue }
            let target = directory.appendingPathComponent(path)
            try fileManager.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
            try fileManager.copyItem(at: source, to: target)
            files.append(path)
        }
        if let preferences = try preferencesData() {
            try preferences.write(to: directory.appendingPathComponent(Self.preferencesFile))
            files.append(Self.preferencesFile)
        }
        let info = Info(version: Self.formatVersion, createdAt: now(), files: files)
        try JSONFileStore<Info>.encoder.encode(info).write(to: directory.appendingPathComponent(Self.infoFile))
    }

    func preferencesData() throws -> Data? {
        guard let defaultsDomain, let domain = UserDefaults.standard.persistentDomain(forName: defaultsDomain) else {
            return nil
        }
        let safe = Self.withoutSecrets(domain)
        return try PropertyListSerialization.data(fromPropertyList: safe, format: .xml, options: 0)
    }

    static func withoutSecrets(_ values: [String: Any]) -> [String: Any] {
        values.filter { key, _ in
            let lowered = key.lowercased().replacingOccurrences(of: "_", with: "")
            return !secretKeyMarkers.contains { lowered.contains($0) }
        }
    }
}
