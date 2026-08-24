import Foundation
import KTPlatformContracts

// Platform conform capability PHP mà feature Dumps cần. File ops nonisolated để quit path
// (block main thread) gọi được; reloadPHPPool ở +Config.swift đã @MainActor.
extension LocalServerController: PHPRuntimeConfiguring {
    public nonisolated var installedPHPVersions: [String] {
        let versions = BundledPHP.availableVersions(php: paths.phpRuntimesRoot)
        return versions.isEmpty ? [BundledPHP.defaultVersion] : versions
    }

    public nonisolated func setAutoPrepend(file: String, version: String) throws {
        try PHPAutoPrepend(paths: paths).set(file: file, version: version)
    }

    public nonisolated func removeAutoPrepend(file: String, version: String) throws {
        try PHPAutoPrepend(paths: paths).remove(file: file, version: version)
    }

    public nonisolated func isAutoPrependSet(file: String, version: String) -> Bool {
        PHPAutoPrepend(paths: paths).isSet(file: file, version: version)
    }
}
