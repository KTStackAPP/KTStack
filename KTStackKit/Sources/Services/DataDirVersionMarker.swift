import Foundation

enum DataDirVersionMarker {
    static let fileName = ".ktstack-version"

    static func verify(_ dataDir: URL, version: String?, kind: ServiceKind) throws {
        guard let version else { return }
        let recorded = recordedVersion(in: dataDir, kind: kind)
        if let recorded, !compatible(recorded, version, kind: kind) {
            throw LaunchdServiceRunner.error(
                "\(kind.displayName) \(version) can't open \(dataDir.path): it holds data written by "
                    + "\(kind.displayName) \(recorded). Switch back to \(recorded), or back up and reset this version's data."
            )
        }
        let marker = dataDir.appendingPathComponent(fileName)
        if recorded == nil || !FileManager.default.fileExists(atPath: marker.path) {
            try? version.write(to: marker, atomically: true, encoding: .utf8)
        }
    }

    static func recordedVersion(in dataDir: URL, kind: ServiceKind) -> String? {
        if kind == .postgres, let pg = read(dataDir.appendingPathComponent("PG_VERSION")) { return pg }
        return read(dataDir.appendingPathComponent(fileName))
    }

    static func compatible(_ recorded: String, _ running: String, kind: ServiceKind) -> Bool {
        let depth = kind == .postgres ? 1 : 2
        return prefix(recorded, depth) == prefix(running, depth)
    }

    private static func prefix(_ version: String, _ depth: Int) -> [String] {
        Array(version.split(whereSeparator: { $0 == "." || $0 == "-" }).prefix(depth).map(String.init))
    }

    private static func read(_ url: URL) -> String? {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
