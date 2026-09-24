import Foundation

extension SiteRegistry {
    static let backupLimit = 5

    struct DecodedSites {
        var sites: [Site]
        var rejected: [Data]
    }

    public struct LoadFailure: LocalizedError {
        public let message: String
        public var errorDescription: String? { message }
    }

    struct UnreadableRegistry: LocalizedError {
        var errorDescription: String? { "sites.json is not a list of sites." }
    }

    nonisolated static func decodeLossy(_ data: Data) throws -> DecodedSites {
        guard let elements = try JSONSerialization.jsonObject(with: data) as? [Any] else { throw UnreadableRegistry() }
        var result = DecodedSites(sites: [], rejected: [])
        for element in elements {
            let raw = try JSONSerialization.data(withJSONObject: element, options: [.sortedKeys])
            if let site = try? JSONDecoder().decode(Site.self, from: raw) {
                result.sites.append(site)
            } else {
                result.rejected.append(raw)
            }
        }
        return result
    }

    func load() {
        let fm = FileManager.default
        guard fm.fileExists(atPath: storeURL.path) else { return }
        do {
            let decoded = try Self.decodeLossy(Data(contentsOf: storeURL))
            sites = decoded.sites
            if !decoded.rejected.isEmpty {
                try saveRejected(decoded.rejected)
                backUpStore()
            }
        } catch {
            loadFailure = "KTStack could not read its site list (\(error.localizedDescription)). "
                + "Sites, vhosts and certificates are left untouched; the file was backed up next to sites.json."
            backUpStore()
        }
        onChange?()
    }

    func persist() {
        guard loadFailure == nil else {
            NSLog("KTStack: not writing sites.json because it failed to load")
            onChange?()
            return
        }
        do {
            try FileManager.default.createDirectory(
                at: storeURL.deletingLastPathComponent(),
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
            backUpStore()
            let data = try JSONEncoder().encode(sites)
            try data.write(to: storeURL, options: .atomic)
        } catch {
            NSLog("KTStack: failed to persist site registry: \(error.localizedDescription)")
        }
        onChange?()
    }

    private func saveRejected(_ rejected: [Data]) throws {
        let body = "[" + rejected.map { String(decoding: $0, as: UTF8.self) }.joined(separator: ",") + "]"
        let url = storeURL.deletingLastPathComponent()
            .appendingPathComponent("sites.rejected-\(Self.stamp()).json")
        try Data(body.utf8).write(to: url, options: .withoutOverwriting)
        NSLog("KTStack: \(rejected.count) unreadable site entries saved to \(url.lastPathComponent)")
    }

    private func backUpStore() {
        let fm = FileManager.default
        guard fm.fileExists(atPath: storeURL.path) else { return }
        let dir = storeURL.deletingLastPathComponent()
        let backup = dir.appendingPathComponent("\(storeURL.lastPathComponent).bak-\(Self.stamp())")
        guard !fm.fileExists(atPath: backup.path) else { return }
        try? fm.copyItem(at: storeURL, to: backup)
        let prefix = "\(storeURL.lastPathComponent).bak-"
        let old = ((try? fm.contentsOfDirectory(atPath: dir.path)) ?? []).filter { $0.hasPrefix(prefix) }.sorted()
        for name in old.dropLast(Self.backupLimit) {
            try? fm.trashItem(at: dir.appendingPathComponent(name), resultingItemURL: nil)
        }
    }

    private nonisolated static func stamp() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss-SSS"
        return formatter.string(from: Date())
    }
}
