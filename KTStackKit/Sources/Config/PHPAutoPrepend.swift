import Foundation
import KTStackCore

// Patch php.ini auto_prepend_file cho một version; filter theo đúng file path nên không đụng
// auto_prepend_file không liên quan của người dùng.
public struct PHPAutoPrepend: Sendable {
    private let paths: AppSupportPaths

    public init(paths: AppSupportPaths = AppSupportPaths()) {
        self.paths = paths
    }

    public func set(file: String, version: String) throws {
        let store = PHPIniStore(paths: paths)
        var ini = try store.read(version: version)
        let line = "auto_prepend_file = \(file)"
        if !ini.contains(line) { ini += "\n\(line)\n" }
        try store.write(version: version, contents: ini)
    }

    public func remove(file: String, version: String) throws {
        let store = PHPIniStore(paths: paths)
        let ini = try store.read(version: version)
        let filtered = ini.components(separatedBy: "\n").filter { !$0.contains(file) }
        try store.write(version: version, contents: filtered.joined(separator: "\n"))
    }

    public func isSet(file: String, version: String) -> Bool {
        guard let ini = try? PHPIniStore(paths: paths).read(version: version) else { return false }
        return ini.contains(file)
    }
}
