import Foundation
import KTPlatformContracts
import KTStackCore

@MainActor
final class RuntimeInspectorModel: ObservableObject {
    let version: String
    let language: RuntimeLanguage
    let sites: [String]
    @Published private(set) var optionalExtensionCount: Int?

    private let phpConfig: any PHPExtensionManaging

    init(version: String, language: RuntimeLanguage, sites: [String], phpConfig: any PHPExtensionManaging) {
        self.version = version
        self.language = language
        self.sites = sites
        self.phpConfig = phpConfig
    }

    /// Đếm extension optional đã cài; chạy khi inspector mở (extensions() là async).
    func load() async {
        guard language == .php else { return }
        let entries = await phpConfig.extensions(phpVersion: version)
        optionalExtensionCount = entries.filter { $0.state == .installed }.count
    }
}
