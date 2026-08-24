import AppKit
import KTDatabasePlugin
import KTPluginKit
import KTStackKit
import KTTunnelPlugin
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
    let connectionStore: ConnectionStore
    let databaseViewModel: DatabaseViewModel
    let documentViewModel: DocumentViewModel
    let tunnels: TunnelManager
    let overlay: KTOverlayCenter

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
            .environmentObject(connectionStore)
            .environmentObject(databaseViewModel)
            .environmentObject(documentViewModel)
            .environmentObject(tunnels)
            .environmentObject(overlay)
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
            SidebarRowModel(from: .settings),
            SidebarRowModel(from: .about),
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
        detailContainer = DetailContainerViewController(nav: nav, env: env, plugins: sections.flatMap(\.plugins))
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        guard modalHost == nil, let window = view.window else { return }
        modalHost = KTModalHostController(parent: window, env: env)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let sidebarController = NSHostingController(rootView: env.inject(DashboardSidebarHost(nav: nav, sections: sections)))
        let sidebarItem = NSSplitViewItem(viewController: sidebarController)
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
    private let nav: DashboardNavigation
    private let env: DashboardEnv
    private let plugins: [any KTStackPlugin]
    private var cache: [String: NSHostingController<AnyView>] = [:]
    private var current: String?
    private var isSectionVisible = false

    init(nav: DashboardNavigation, env: DashboardEnv, plugins: [any KTStackPlugin]) {
        self.nav = nav
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
        let previous = current

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
        if isSectionVisible { notifyActivation(from: previous, to: id) }
        DispatchQueue.main.async { [nav] in nav.activeItem = id }
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        guard !isSectionVisible else { return }
        isSectionVisible = true
        notifyActivation(from: nil, to: current)
    }

    override func viewDidDisappear() {
        super.viewDidDisappear()
        guard isSectionVisible else { return }
        isSectionVisible = false
        notifyActivation(from: current, to: nil)
    }

    private func notifyActivation(from oldID: String?, to newID: String?) {
        plugin(for: oldID)?.sectionDidDeactivate()
        plugin(for: newID)?.sectionDidActivate()
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
    }

    @ViewBuilder
    private func detailContent(for id: String) -> some View {
        if let plugin = plugins.first(where: { $0.descriptor.id == id }) {
            plugin.makeContentView()
        } else if id == SidebarItem.settings.rawValue {
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
            .navigationTitle("Settings")
        } else if id == SidebarItem.about.rawValue {
            AboutSettingsView().navigationTitle("About")
        }
    }
}
