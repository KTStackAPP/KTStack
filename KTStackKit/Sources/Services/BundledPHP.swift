import Foundation
import KTStackCore

public enum BundledPHP {
    public static let defaultVersion = "8.4"

    // Bám theo manifest để thêm bản PHP mới chỉ cần sửa RuntimeCatalog
    public static let plannedVersions: [String] =
        RuntimeCatalog.manifest.filter { $0.language == .php }.map(\.version)

    public static let endOfLifeVersions: Set<String> = ["7.4", "8.0", "8.1"]

    public static func isEndOfLife(_ version: String) -> Bool {
        endOfLifeVersions.contains(version)
    }

    public static func fpmBinary(for version: String, php runtimeRoot: URL) -> URL {
        runtimeRoot.appendingPathComponent(version, isDirectory: true)
            .appendingPathComponent("bin", isDirectory: true)
            .appendingPathComponent("php-fpm")
    }

    public static func availableVersions(php runtimeRoot: URL, fileManager: FileManager = .default) -> [String] {
        guard let entries = try? fileManager.contentsOfDirectory(atPath: runtimeRoot.path) else { return [] }
        return entries
            .filter { fileManager.isExecutableFile(atPath: fpmBinary(for: $0, php: runtimeRoot).path) }
            .sorted()
    }
}
