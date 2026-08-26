import Foundation
import KTPlatformContracts
import KTStackCore

public struct PHPPoolSettingsStore: Sendable {
    private let paths: AppSupportPaths
    private var fileManager: FileManager {
        .default
    }

    public init(paths: AppSupportPaths = AppSupportPaths()) {
        self.paths = paths
    }

    // Thiếu file → default; file có nhưng hỏng → throw (không im lặng ghi đè cấu hình xấu).
    public func load(version: String) throws -> PHPPoolSettings {
        let url = paths.phpPoolSettings(version: version)
        guard fileManager.fileExists(atPath: url.path) else { return .default }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(PHPPoolSettings.self, from: data)
    }

    public func write(version: String, settings: PHPPoolSettings) throws {
        try fileManager.createDirectory(
            at: paths.phpIniDir(version: version),
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        let url = paths.phpPoolSettings(version: version)
        if fileManager.fileExists(atPath: url.path) {
            let bak = backupURL(version: version)
            try? fileManager.removeItem(at: bak)
            try? fileManager.copyItem(at: url, to: bak)
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(settings).write(to: url, options: .atomic)
    }

    @discardableResult
    public func restoreBackup(version: String) throws -> Bool {
        let bak = backupURL(version: version)
        guard fileManager.fileExists(atPath: bak.path) else { return false }
        let url = paths.phpPoolSettings(version: version)
        try? fileManager.removeItem(at: url)
        try fileManager.copyItem(at: bak, to: url)
        return true
    }

    private func backupURL(version: String) -> URL {
        paths.phpPoolSettings(version: version).appendingPathExtension("bak")
    }
}
