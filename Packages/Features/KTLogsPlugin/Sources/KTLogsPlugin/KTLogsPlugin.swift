import KTPlatformContracts
import KTPluginKit
import SwiftUI

public final class KTLogsPlugin: KTStackPlugin, SectionActivationObserving {
    public let descriptor = PluginDescriptor(id: "logs", title: "Logs", systemImage: "text.alignleft")

    private let context: any LogSourceContextProviding
    @MainActor private lazy var store = LogsStore(context: context)

    public init(context: any LogSourceContextProviding) { self.context = context }

    @MainActor public func makeContentView() -> AnyView {
        AnyView(LogsSectionView(store: store))
    }

    // Deep-link entry: AppDelegate nối navigation.openLogsHandler vào đây.
    @MainActor public func show(sourceID: String?) { store.show(sourceID: sourceID) }

    // Tail chỉ chạy khi tab Logs active và window mở; rời tab hoặc đóng window thì dừng (fix leak).
    @MainActor public func sectionDidActivate() { store.activate() }
    @MainActor public func sectionDidDeactivate() { store.deactivate() }
}
