import AppKit
import KTPlatformContracts
import KTPluginKit
import KTStackCore
import ServiceManagement

@MainActor
final class DoctorViewModel: ObservableObject {
    @Published private(set) var report: DoctorReport?
    @Published private(set) var isRunning = false
    @Published private(set) var didCopy = false

    private let probes: any DoctorProbing
    private let paths: AppSupportPaths
    private let tld: @MainActor () -> String
    private let registry: @MainActor () -> [any KTStackPlugin]
    private let route: @MainActor (DoctorRoute) -> Void
    private var copyResetTask: Task<Void, Never>?

    init(
        probes: any DoctorProbing,
        paths: AppSupportPaths,
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

    func run() async {
        guard !isRunning else { return }
        isRunning = true
        let providers = registry().compactMap { $0 as? any DoctorCheckProviding }
        let service = DoctorService(paths: paths, tld: tld(), probes: probes)
        report = await service.run(providers: providers)
        isRunning = false
    }

    func copyReport() {
        guard let report else { return }
        let text = DoctorReportFormatter().text(for: report)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        didCopy = true
        // Bấm Copy liên tiếp: hủy reset cũ để nhãn "Copied" không tắt sớm.
        copyResetTask?.cancel()
        copyResetTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled else { return }
            self?.didCopy = false
        }
    }

    func perform(_ action: DoctorRemedyAction) {
        switch action {
        case .openLoginItems:
            if #available(macOS 13, *) { SMAppService.openSystemSettingsLoginItems() }
        case .openServices: route(.services)
        case .openSettings: route(.settings)
        case .openRuntimes: route(.runtimes)
        }
    }
}
