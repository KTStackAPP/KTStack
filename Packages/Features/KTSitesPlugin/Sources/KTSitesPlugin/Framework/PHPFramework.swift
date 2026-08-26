import Foundation

enum PHPFramework: String, Sendable, Equatable {
    case wordpress
    case laravel
    case plain

    var label: String {
        switch self {
        case .wordpress: "WordPress"
        case .laravel: "Laravel"
        case .plain: "PHP"
        }
    }
}

struct PHPFrameworkDetector: Sendable {
    private let laravel = LaravelSiteProbe()
    private let wordpress = WordPressSiteProbe()

    func detect(
        siteAt folder: URL,
        docroot: URL? = nil,
        fileManager: FileManager = .default
    ) -> PHPFramework {
        if laravel.isLaravel(siteAt: folder, fileManager: fileManager) { return .laravel }
        if wordpress.isWordPress(siteAt: folder, docroot: docroot, fileManager: fileManager) { return .wordpress }
        return .plain
    }
}
