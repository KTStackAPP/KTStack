import KTPlatformContracts
import KTPluginKit
import SwiftUI

extension SiteInspector {
    func runtimeCard(_ site: SiteSummary) -> some View {
        InspectorCard(title: "Runtime") {
            switch site.kind {
            case .php: phpRows(site)
            case .node: nodeRows(site)
            case .proxy: proxyRows(site)
            case .staticSite: staticRows(site)
            }
        }
    }

    @ViewBuilder
    private func phpRows(_ site: SiteSummary) -> some View {
        InspectorRow("Framework") {
            KTBadge(text: framework(site).label, tint: SiteVisuals.tint(for: framework(site)), radius: 6)
        } trailing: {
            if !site.path.isEmpty {
                InspectorButton(title: "Recheck", style: .quiet) { actions.recheckType(site) }
            }
        }
        InspectorRow("PHP") {
            HStack(spacing: 8) {
                PhpMenu(current: site.phpVersion, versions: vm.server.phpVersions, onSelect: { vm.setPHP(site.id, $0) })
                if vm.isEndOfLife(site.phpVersion) {
                    InspectorHint("End of life", color: Color(nsColor: .systemOrange))
                }
            }
        }
        InspectorRow("Web server") {
            EngineControl(
                current: site.engine,
                port: site.backendPort,
                apacheInstalled: vm.webEngine.installed,
                apacheInstalling: vm.webEngine.installing,
                onSelect: { vm.setEngine(site.id, $0) },
                onInstallApache: vm.installApache
            )
        }
        if !site.path.isEmpty {
            InspectorRow("Workers") {
                InspectorValue(SiteDetailSummary.workers(vm.workersSummary(for: site)))
            } trailing: {
                InspectorButton(title: "Manage…") { sheet = .workers }
            }
        }
    }

    @ViewBuilder
    private func staticRows(_ site: SiteSummary) -> some View {
        InspectorRow("Serves") {
            InspectorHint("Files from the folder, no PHP")
        } trailing: {
            InspectorButton(title: "Recheck type", style: .quiet) { actions.recheckType(site) }
        }
        InspectorRow("Folder") {
            InspectorValue(site.docroot.isEmpty ? site.path : site.docroot, truncation: .middle)
        }
    }

    @ViewBuilder
    private func nodeRows(_ site: SiteSummary) -> some View {
        InspectorRow("Proxies to") {
            NodePortEditor(site: site, save: { try vm.setNodePort(site.id, $0) })
        }
        InspectorRow("Status") {
            if let port = site.nodePort {
                if upstreamRunning(site) {
                    StatusBadge(text: "Listening on :\(port)")
                } else {
                    InspectorHint("Nothing on :\(port)")
                }
            } else {
                InspectorHint("Set a port to route this site")
            }
        } trailing: {
            if site.nodePort != nil, !upstreamRunning(site) {
                InspectorButton(title: "Start in Terminal") { SiteActions.startNodeInTerminal(site) }
                    .ktTip("Open Terminal at the project with PORT set; run your dev server there")
            }
        }
        InspectorRow("Start command") {
            InspectorValue(site.nodeCommand ?? "auto", muted: site.nodeCommand == nil)
        }
    }

    @ViewBuilder
    private func proxyRows(_ site: SiteSummary) -> some View {
        InspectorRow("Upstream") {
            ProxyTargetEditor(site: site, save: { try vm.setProxyTarget(site.id, $0) })
        }
        InspectorRow("Status") {
            VStack(alignment: .leading, spacing: 4) {
                if upstreamRunning(site) {
                    StatusBadge(text: "Reachable")
                } else {
                    InspectorHint("Not reachable")
                }
                InspectorHint("TCP check only, KTStack does not run it")
            }
        }
    }
}

private struct StatusBadge: View {
    let text: String

    var body: some View {
        KTBadge(text: text, tint: KTTint(fg: KTColor.online, bg: KTColor.onlineBg), radius: 6)
    }
}

private struct NodePortEditor: View {
    let site: SiteSummary
    let save: (Int?) throws -> Void

    @State private var draft: String
    @State private var error: String?

    init(site: SiteSummary, save: @escaping (Int?) throws -> Void) {
        self.site = site
        self.save = save
        _draft = State(initialValue: Self.display(site.nodePort))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Text("localhost:").font(.jbMono(12.5)).foregroundStyle(KTColor.muted)
                TextField("3000", text: $draft)
                    .textFieldStyle(.roundedBorder)
                    .font(.jbMono(12.5))
                    .frame(width: 80)
                    .onSubmit(commit)
                    .ktTip("Port your Node app listens on; KTStack proxies this site to it")
                    .accessibilityLabel("Node port for \(site.domain)")
            }
            if let error { InspectorError(error) }
        }
        .onChange(of: site.nodePort) { new in draft = Self.display(new) }
    }

    private func commit() {
        switch SiteInspectorInput.nodePort(draft) {
        case .clear:
            try? save(nil)
            error = nil
        case .invalid:
            restore("Enter a port between 1 and 65535.")
        case let .port(port):
            do {
                try save(port)
                error = nil
            } catch {
                restore(error.localizedDescription)
            }
        }
    }

    private func restore(_ message: String) {
        draft = Self.display(site.nodePort)
        error = message
    }

    private static func display(_ port: Int?) -> String {
        port.map(String.init) ?? ""
    }
}

private struct ProxyTargetEditor: View {
    let site: SiteSummary
    let save: (String) throws -> Void

    @State private var draft: String
    @State private var error: String?

    init(site: SiteSummary, save: @escaping (String) throws -> Void) {
        self.site = site
        self.save = save
        _draft = State(initialValue: SiteInspectorInput.proxyDisplay(site.proxyTarget))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            TextField("http://127.0.0.1:8000", text: $draft)
                .textFieldStyle(.roundedBorder)
                .font(.jbMono(12.5))
                .onSubmit(commit)
                .ktTip("Upstream KTStack proxies this site to; KTStack does not run it")
                .accessibilityLabel("Proxy target for \(site.domain)")
            if let error { InspectorError(error) }
        }
        .onChange(of: site.proxyTarget) { new in draft = SiteInspectorInput.proxyDisplay(new) }
    }

    private func commit() {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        let current = SiteInspectorInput.proxyDisplay(site.proxyTarget)
        guard trimmed != current else { return }
        do {
            try save(trimmed)
            error = nil
        } catch {
            draft = current
            self.error = error.localizedDescription
        }
    }
}
