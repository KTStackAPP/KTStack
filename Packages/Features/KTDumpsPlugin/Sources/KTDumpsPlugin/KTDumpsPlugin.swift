import KTPlatformContracts
import KTPluginKit
import SwiftUI

public final class KTDumpsPlugin: KTStackPlugin, PluginLifecycle {
    public let descriptor = PluginDescriptor(id: "dumps", title: "Dumps", systemImage: "curlybraces")

    private let php: any PHPRuntimeConfiguring
    private let server = DumpServer()
    private let injector: DumpInjector
    @MainActor private lazy var model = DumpsViewModel(php: php, server: server, injector: injector)

    public init(php: any PHPRuntimeConfiguring) {
        self.php = php
        injector = DumpInjector(php: php)
    }

    @MainActor public func makeContentView() -> AnyView {
        AnyView(DumpsPanelView(model: model))
    }

    public func start() async {}

    // Quit cleanup: chỉ file ops (nonisolated) vì applicationWillTerminate block main thread.
    // Không reloadPHPPool: server sắp bootout và hop MainActor lúc quit sẽ deadlock.
    public func shutdown() async {
        for version in php.installedPHPVersions where injector.isEnabled(version: version) {
            try? injector.disable(version: version)
        }
        injector.cleanupPrependFile()
        server.stop()
    }
}
