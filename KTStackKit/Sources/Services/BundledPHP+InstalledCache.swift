import Foundation

public extension BundledPHP {
    static func cachedAvailableVersions(php runtimeRoot: URL) -> [String] {
        InstalledPHPCache.shared.versions(php: runtimeRoot)
    }
}

final class InstalledPHPCache: @unchecked Sendable {
    static let shared = InstalledPHPCache()

    private let lock = NSLock()
    private var entries: [String: (stamp: Stamp, versions: [String])] = [:]

    private struct Stamp: Equatable {
        let modified: Date
        let links: Int
    }

    func versions(php runtimeRoot: URL) -> [String] {
        let attributes = try? FileManager.default.attributesOfItem(atPath: runtimeRoot.path)
        let stamp = Stamp(
            modified: attributes?[.modificationDate] as? Date ?? .distantPast,
            links: (attributes?[.referenceCount] as? NSNumber)?.intValue ?? 0
        )
        if let hit = lock.withLock({ entries[runtimeRoot.path] }), hit.stamp == stamp { return hit.versions }
        let versions = BundledPHP.availableVersions(php: runtimeRoot)
        lock.withLock { entries[runtimeRoot.path] = (stamp, versions) }
        return versions
    }
}
