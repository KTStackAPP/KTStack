import Foundation
import KTPlatformContracts
import KTStackCore

// RouteIntrospector ở lại platform (cần php binary + env imagick qua InstallCommandRunner). Service
// resolve phpBinary/phpIni từ AppSupportPaths; ini nil khi file chưa tồn tại (như VM cũ ngầm định).
public struct RouteIntrospectionService: APIRouteIntrospecting {
    private let paths: AppSupportPaths

    public init(paths: AppSupportPaths = AppSupportPaths()) {
        self.paths = paths
    }

    public func introspectRoutes(siteFolder: URL, phpVersion: String) async throws -> RouteIntrospectionOutcome {
        let php = paths.phpBinary(version: phpVersion)
        let phpIni = Self.resolvedIni(paths.phpIni(version: phpVersion))
        return try await RouteIntrospector(php: php, phpIni: phpIni).routes(siteAt: siteFolder)
    }

    static func resolvedIni(_ url: URL) -> URL? {
        FileManager.default.fileExists(atPath: url.path) ? url : nil
    }
}
