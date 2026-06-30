import Foundation

public enum WebServerBackendFactory {
    public static func backend(for engine: WebServerEngine, paths: AppSupportPaths) -> WebServerBackend {
        switch engine {
        case .nginx:
            NginxBackend()
        case .apache:
            ApacheBackend(serverRoot: paths.apacheRoot)
        }
    }

    // A site may persist `.apache` before (or without) the on-demand binary being installed.
    // Resolve to the engine that can actually run: apache only when its binary is present, else
    // fall back to nginx loudly so the site serves on the front's bundled engine, never broken.
    public static func effectiveEngine(_ requested: WebServerEngine, paths: AppSupportPaths) -> WebServerEngine {
        guard requested == .apache else { return requested }
        if paths.apacheAvailable() { return .apache }
        NSLog("KTStack: Apache backend not installed; falling back to nginx for this site.")
        return .nginx
    }
}
