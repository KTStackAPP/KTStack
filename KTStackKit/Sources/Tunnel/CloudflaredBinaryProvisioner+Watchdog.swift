import Foundation

extension CloudflaredBinaryProvisioner {
    public nonisolated var watchdogExecutable: URL? {
        guard let url = Bundle.main.url(forAuxiliaryExecutable: "kt"),
              FileManager.default.isExecutableFile(atPath: url.path) else { return nil }
        return url
    }
}
