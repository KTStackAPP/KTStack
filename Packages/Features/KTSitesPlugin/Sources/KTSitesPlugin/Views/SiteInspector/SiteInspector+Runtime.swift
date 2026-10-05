import KTPlatformContracts
import KTPluginKit
import SwiftUI

extension SiteInspector {
    func runtimeGroup(_ site: SiteSummary) -> some View {
        InspectorGroup(title: "Runtime") {
            switch site.kind {
            case .php: phpFields(site)
            case .node: nodeFields(site)
            case .proxy: proxyFields(site)
            case .staticSite:
                InspectorField("Folder") {
                    InspectorValue(site.docroot.isEmpty ? site.path : site.docroot, truncation: .middle)
                }
            }
        }
    }

    @ViewBuilder
    private func phpFields(_ site: SiteSummary) -> some View {
        InspectorField("Framework") {
            HStack(spacing: 8) {
                InspectorValue(framework(site).label)
                if !site.path.isEmpty {
                    KTButton(title: "Recheck", kind: .link) { actions.recheckType(site) }
                }
            }
        }
        InspectorField("PHP") {
            HStack(spacing: 8) {
                PhpMenu(current: site.phpVersion, versions: vm.server.phpVersions, onSelect: { vm.setPHP(site.id, $0) })
                if vm.isEndOfLife(site.phpVersion) {
                    KTBadge(text: "End of life", tint: KTTint(fg: KTColor.danger, bg: KTColor.dangerBg), radius: 8)
                }
            }
        }
        InspectorField("Web server") {
            EngineMenu(
                current: site.engine,
                port: site.backendPort,
                apacheInstalled: vm.webEngine.installed,
                apacheInstalling: vm.webEngine.installing,
                onSelect: { vm.setEngine(site.id, $0) },
                onInstallApache: vm.installApache
            )
        }
        if !site.path.isEmpty {
            SiteWorkersSection(siteID: site.id, vm: vm)
        }
    }

    @ViewBuilder
    private func nodeFields(_ site: SiteSummary) -> some View {
        InspectorField("Port") {
            NodePortEditor(site: site, save: { try vm.setNodePort(site.id, $0) }, reportError: actions.reportError)
        }
        InspectorField("Status") { UpstreamStatus(running: upstreamRunning(site)) }
        InspectorField("Start") {
            if site.nodePort != nil {
                KTButton(title: "Start in Terminal", kind: .secondary) { SiteActions.startNodeInTerminal(site) }
                    .ktTip("Open Terminal at the project with PORT set; run your dev server there")
            } else {
                InspectorValue("Set a port to route this site", muted: true)
            }
        }
        InspectorField("Start command") {
            InspectorValue(site.nodeCommand ?? "auto", muted: site.nodeCommand == nil)
        }
    }

    @ViewBuilder
    private func proxyFields(_ site: SiteSummary) -> some View {
        InspectorField("Upstream") {
            ProxyTargetEditor(site: site, save: { try vm.setProxyTarget(site.id, $0) }, reportError: actions.reportError)
        }
        InspectorField("Status") { UpstreamStatus(running: upstreamRunning(site)) }
    }
}

private struct UpstreamStatus: View {
    let running: Bool

    var body: some View {
        HStack(spacing: 6) {
            KTDot(color: running ? KTColor.runDot : KTColor.stopDot)
            Text(running ? "Reachable" : "Not reachable")
                .font(.jbMono(12.5))
                .foregroundStyle(running ? KTColor.online : KTColor.ink3)
        }
    }
}

private struct NodePortEditor: View {
    let site: SiteSummary
    let save: (Int?) throws -> Void
    let reportError: (String) -> Void

    @State private var draft: String
    @State private var error: String?

    init(site: SiteSummary, save: @escaping (Int?) throws -> Void, reportError: @escaping (String) -> Void) {
        self.site = site
        self.save = save
        self.reportError = reportError
        _draft = State(initialValue: site.nodePort.map(String.init) ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Text("localhost:").font(.jbMono(12.5)).foregroundStyle(KTColor.faint)
                TextField("port", text: $draft)
                    .textFieldStyle(.roundedBorder)
                    .font(.jbMono(12.5))
                    .frame(width: 80)
                    .onSubmit(commit)
                    .ktTip("Port your Node app listens on; KTStack proxies this site to it")
                    .accessibilityLabel("Node port for \(site.domain)")
            }
            if let error { InspectorError(error) }
        }
        .onChange(of: site.nodePort) { new in draft = new.map(String.init) ?? "" }
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
        draft = site.nodePort.map(String.init) ?? ""
        error = message
        reportError(message)
    }
}

private struct ProxyTargetEditor: View {
    let site: SiteSummary
    let save: (String) throws -> Void
    let reportError: (String) -> Void

    @State private var draft: String
    @State private var error: String?

    init(site: SiteSummary, save: @escaping (String) throws -> Void, reportError: @escaping (String) -> Void) {
        self.site = site
        self.save = save
        self.reportError = reportError
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
            reportError(error.localizedDescription)
        }
    }
}
