import Foundation
import KTPlatformContracts
import KTStackCore

@MainActor
final class RuntimeInspectorModel: ObservableObject {
    let version: String
    let language: RuntimeLanguage
    let sites: [String]
    @Published private(set) var optionalExtensionCount: Int?
    @Published private(set) var poolSummary: String?

    private let phpConfig: any PHPExtensionManaging & PHPPoolEditing

    init(version: String, language: RuntimeLanguage, sites: [String], phpConfig: any PHPExtensionManaging & PHPPoolEditing) {
        self.version = version
        self.language = language
        self.sites = sites
        self.phpConfig = phpConfig
    }

    /// Đếm extension optional đã cài + tóm tắt pool; chạy khi inspector mở (extensions() là async).
    func load() async {
        guard language == .php else { return }
        let entries = await phpConfig.extensions(phpVersion: version)
        optionalExtensionCount = entries.filter { $0.state == .installed }.count
        let settings = (try? phpConfig.poolSettings(phpVersion: version)) ?? phpConfig.defaultPoolSettings
        poolSummary = "\(settings.processManager.rawValue) · \(settings.maxChildren) max children"
    }
}
