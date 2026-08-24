import KTPlatformContracts
import KTPluginKit
import KTStackCore
import SwiftUI

// Sidebar plugin, không lifecycle/activation: Doctor read-only, chạy checks khi tab hiện.
public final class KTDoctorPlugin: KTStackPlugin {
    public let descriptor = PluginDescriptor(id: "doctor", title: "Doctor", systemImage: "stethoscope")

    private let probes: any DoctorProbing
    private let paths: AppSupportPaths
    private let tld: @MainActor () -> String
    private let registry: @MainActor () -> [any KTStackPlugin]
    private let route: @MainActor (DoctorRoute) -> Void

    @MainActor private lazy var model = DoctorViewModel(
        probes: probes, paths: paths, tld: tld, registry: registry, route: route
    )

    public init(
        probes: any DoctorProbing,
        paths: AppSupportPaths = .init(),
        tld: @escaping @MainActor () -> String,
        registry: @escaping @MainActor () -> [any KTStackPlugin],
        route: @escaping @MainActor (DoctorRoute) -> Void
    ) {
        self.probes = probes
        self.paths = paths
        self.tld = tld
        self.registry = registry
        self.route = route
    }

    @MainActor public func makeContentView() -> AnyView {
        AnyView(DoctorSectionView(model: model))
    }
}
