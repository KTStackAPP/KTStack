import KTPlatformContracts
import KTPluginKit
import SwiftUI

/// Sidebar plugin sở hữu màn Runtimes. Stream subscribe lazy khi VM khởi tạo (makeContentView đầu
/// tiên); không lifecycle/activation, không resource cần dọn lúc quit.
public final class KTRuntimesPlugin: KTStackPlugin {
    public let descriptor = PluginDescriptor(id: "runtimes", title: "Runtimes", systemImage: "cube")

    private let runtimes: any RuntimeManaging
    private let webEngine: any WebEngineProvisioning
    private let phpSites: any PHPSiteRuntimeProviding
    private let phpConfig: any PHPExtensionManaging & PHPIniEditing & PHPPoolEditing
    private let engines: any ServiceEngineVersionManaging

    @MainActor private lazy var runtimesVM = RuntimesViewModel(
        runtimes: runtimes, webEngine: webEngine, phpSites: phpSites
    )
    @MainActor private lazy var enginesVM = EngineVersionsViewModel(engines: engines)
    @MainActor private let feedback = KTFeedbackCenter()

    public init(
        runtimes: any RuntimeManaging,
        webEngine: any WebEngineProvisioning,
        phpSites: any PHPSiteRuntimeProviding,
        phpConfig: any PHPExtensionManaging & PHPIniEditing & PHPPoolEditing,
        engines: any ServiceEngineVersionManaging
    ) {
        self.runtimes = runtimes
        self.webEngine = webEngine
        self.phpSites = phpSites
        self.phpConfig = phpConfig
        self.engines = engines
    }

    @MainActor
    public func makeContentView() -> AnyView {
        AnyView(
            RuntimesScreen(vm: runtimesVM, engines: enginesVM, phpConfig: phpConfig)
                .environmentObject(feedback)
        )
    }
}
