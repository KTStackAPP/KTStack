import Foundation

public struct SiteRuntimePins: Sendable {
    private let storeURL: URL

    public init(paths: AppSupportPaths) {
        storeURL = paths.sitesRegistryFile
    }

    public init(storeURL: URL) {
        self.storeURL = storeURL
    }

    public func phpVersion(forProjectAt cwd: URL) -> String? {
        let target = cwd.standardizedFileURL.path
        // Trailing slash stops /foo matching /foobar; longest matching path wins so a nested
        // site's pin overrides an ancestor's.
        return load()
            .filter { pin in
                guard pin.isPHPProject, let version = pin.phpVersion, !version.isEmpty else { return false }
                let root = pin.standardizedPath
                return target == root || target.hasPrefix(root + "/")
            }
            .max { $0.standardizedPath.count < $1.standardizedPath.count }?
            .phpVersion
    }

    private func load() -> [Pin] {
        guard let data = try? Data(contentsOf: storeURL),
              let entries = try? JSONDecoder().decode([OptionalPin].self, from: data) else { return [] }
        return entries.compactMap(\.pin)
    }

    private struct OptionalPin: Decodable {
        let pin: Pin?

        init(from decoder: Decoder) throws {
            pin = try? Pin(from: decoder)
        }
    }

    private struct Pin: Decodable {
        let path: String
        let phpVersion: String?
        let type: String?

        var isPHPProject: Bool {
            path.hasPrefix("/") && (type == nil || type == "php")
        }

        var standardizedPath: String {
            URL(fileURLWithPath: path).standardizedFileURL.path
        }
    }
}
