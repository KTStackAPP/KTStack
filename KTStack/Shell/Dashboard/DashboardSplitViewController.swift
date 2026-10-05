import AppKit
import KTPluginKit
import KTStackKit
import SwiftUI

struct DashboardEnv {
    let preferences: AppPreferences
    let server: LocalServerController
    let dns: DNSAutomationService
    let services: ServiceManager
    let runtimes: RuntimeManager
    let caTrust: CATrustService
    let updater: UpdaterController
    let uninstaller: UninstallService
    let modals: KTModalPresenter
    let standaloneSettings: [any SettingsProviding]

    func inject(_ view: some View) -> some View {
        view
            .environmentObject(preferences)
            .environmentObject(server)
            .environmentObject(dns)
            .environmentObject(services)
            .environmentObject(runtimes)
            .environmentObject(caTrust)
            .environmentObject(updater)
            .environmentObject(uninstaller)
            .environmentObject(modals)
    }
}

struct DashboardSplitRepresentable: NSViewControllerRepresentable {
    @ObservedObject var nav: DashboardNavigation
    let env: DashboardEnv
    let sections: [PluginSection]

    func makeNSViewController(context _: Context) -> DashboardSplitViewController {
        DashboardSplitViewController(nav: nav, env: env, sections: sections)
    }

    func updateNSViewController(_ controller: DashboardSplitViewController, context _: Context) {
        controller.show(nav.selection)
    }
}

private struct DashboardSidebarHost: View {
    @ObservedObject var nav: DashboardNavigation
    let sections: [PluginSection]
    @EnvironmentObject private var server: LocalServerController

    var body: some View {
        KTSidebar(
            sections: sidebarSections,
            selection: Binding(get: { nav.selection }, set: { nav.selection = $0 }),
            siteCount: server.registry.sites.count,
            serverStatus: serverStatus,
            version: versionText
        )
        .ignoresSafeArea(.container, edges: .top)
    }

    // Nhóm plugin từ registry + nhóm APP là shell rows (settings/about), không vào registry.
    private var sidebarSections: [KTSidebarGroup] {
        var groups = sections.map { section in
            KTSidebarGroup(title: section.title.uppercased(), rows: section.plugins.map {
                SidebarRowModel(id: $0.descriptor.id, title: $0.descriptor.title, symbol: $0.descriptor.systemImage)
            })
        }
        groups.append(KTSidebarGroup(title: "APP", rows: [
            SidebarRowModel(id: "settings", title: "Settings", symbol: "gearshape"),
            SidebarRowModel(id: "about", title: "About", symbol: "info.circle"),
        ]))
        return groups
    }

    private var serverStatus: ServiceStatus {
        if server.nginxStatus == .starting || server.nginxStatus == .error || server.nginxStatus == .warning {
            return server.nginxStatus
        }
        return server.isRunning ? .running : .stopped
    }

    private var versionText: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
    }
}

final class DashboardSplitViewController: NSSplitViewController {
    private let nav: DashboardNavigation
    private let env: DashboardEnv
    private let sections: [PluginSection]
    private let detailContainer: DetailContainerViewController
    private var modalHost: KTModalHostController?

    init(nav: DashboardNavigation, env: DashboardEnv, sections: [PluginSection]) {
        self.nav = nav
        self.env = env
        self.sections = sections
        detailContainer = DetailContainerViewController(env: env, plugins: sections.flatMap(\.plugins))
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        guard modalHost == nil, let window = view.window else { return }
        modalHost = KTModalHostController(parent: window, modals: env.modals)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let sidebarController = NSHostingController(rootView: env.inject(DashboardSidebarHost(nav: nav, sections: sections)))
        let sidebarItem = NSSplitViewItem(sidebarWithViewController: sidebarController)
        sidebarItem.canCollapse = false
        sidebarItem.minimumThickness = KTMetric.sidebarWidth
        sidebarItem.maximumThickness = KTMetric.sidebarWidth
        let detailItem = NSSplitViewItem(viewController: detailContainer)
        detailItem.canCollapse = false

        addSplitViewItem(sidebarItem)
        addSplitViewItem(detailItem)

        splitView.dividerStyle = .thin
        detailContainer.show(nav.selection)
    }

    func show(_ id: String) {
        detailContainer.show(id)
    }
}

final class DetailContainerViewController: NSViewController {
    private let env: DashboardEnv
    private let plugins: [any KTStackPlugin]
    private var cache: [String: NSHostingController<AnyView>] = [:]
    private var current: String?
    private var isSectionVisible = false
    // Section whose sectionDidActivate has run; activation is deferred, so it can lag `current`.
    private var activatedID: String?
    private var pendingActivation: Task<Void, Never>?

    // Let the newly shown section paint before its activation work (log tail load, upstream probes,
    // polling) lands on the main thread. A short sleep rather than main.async: an async block can run
    // in the same run-loop pass, before the display commit.
    private static let activationDelay: UInt64 = 50_000_000

    init(env: DashboardEnv, plugins: [any KTStackPlugin]) {
        self.env = env
        self.plugins = plugins
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func loadView() {
        let container = NSView()
        container.wantsLayer = true
        view = container
    }

    func show(_ id: String) {
        if current == id { return }

        let controller = cache[id] ?? makeController(id)
        cache[id] = controller

        if let previous = current, let previousController = cache[previous] {
            view.window?.makeFirstResponder(nil)
            previousController.view.isHidden = true
        }

        if controller.parent == nil {
            addChild(controller)
            controller.view.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(controller.view)
            NSLayoutConstraint.activate([
                controller.view.topAnchor.constraint(equalTo: view.topAnchor),
                controller.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
                controller.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                controller.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            ])
        }

        controller.view.isHidden = false
        current = id
        if isSectionVisible { activateSection(id) }
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        guard !isSectionVisible else { return }
        isSectionVisible = true
        activateSection(current)
    }

    override func viewDidDisappear() {
        super.viewDidDisappear()
        guard isSectionVisible else { return }
        isSectionVisible = false
        activateSection(nil)
    }

    // Deactivates the previous section now and activates `id` after the delay, unless the user has
    // moved on by then. A section skipped by a quick switch is never activated, so never deactivated.
    private func activateSection(_ id: String?) {
        pendingActivation?.cancel()
        pendingActivation = nil
        if let activatedID, activatedID != id {
            plugin(for: activatedID)?.sectionDidDeactivate()
            self.activatedID = nil
        }
        guard let id, activatedID != id else { return }
        pendingActivation = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: Self.activationDelay)
            guard let self, !Task.isCancelled, current == id, isSectionVisible else { return }
            pendingActivation = nil
            activatedID = id
            plugin(for: id)?.sectionDidActivate()
        }
    }

    private func plugin(for id: String?) -> (any SectionActivationObserving)? {
        guard let id else { return nil }
        return plugins.first { $0.descriptor.id == id } as? any SectionActivationObserving
    }

    private func makeController(_ id: String) -> NSHostingController<AnyView> {
        let content = VStack(spacing: 0) {
            Color.clear.frame(height: KTMetric.trafficLightInset - 18)
            detailContent(for: id)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(KTColor.contentBg)
        .ignoresSafeArea(.container, edges: .top)

        return NSHostingController(rootView: AnyView(env.inject(content)))
    }

    private var settingsPanes: [AnyView] {
        plugins.compactMap { ($0 as? any SettingsProviding)?.makeSettingsPane() }
            + env.standaloneSettings.map { $0.makeSettingsPane() }
    }

    @ViewBuilder
    private func detailContent(for id: String) -> some View {
        if let plugin = plugins.first(where: { $0.descriptor.id == id }) {
            plugin.makeContentView()
        } else if id == "settings" {
            SettingsView(
                preferences: env.preferences,
                dns: env.dns,
                server: env.server,
                runtimes: env.runtimes,
                caTrust: env.caTrust,
                updater: env.updater,
                uninstaller: env.uninstaller,
                pluginPanes: settingsPanes
            )
        } else if id == "about" {
            AboutSettingsView()
        }
    }
}
