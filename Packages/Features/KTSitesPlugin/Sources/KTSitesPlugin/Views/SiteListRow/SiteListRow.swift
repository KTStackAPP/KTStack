import KTPlatformContracts
import KTPluginKit
import SwiftUI

struct SiteListRow: View, Equatable {
    let site: SiteSummary
    let availableVersions: [String]
    let canOpen: Bool
    let nodeRunning: Bool
    let share: SiteShareState?
    let framework: PHPFramework
    let apacheInstalled: Bool
    let apacheInstalling: Bool
    let onOpen: () -> Void
    let onSetVersion: (String) -> Void
    let onSetSecure: (Bool) -> Void
    let onSetEngine: (SiteServerEngine) -> Void
    let onInstallApache: () -> Void
    let onEditDomain: (String) throws -> Void
    let onSetNodePort: (Int?) throws -> Void
    let onOpenLogs: () -> Void
    let onOpenAPITester: () -> Void
    let onToggleShare: (Bool) -> Void
    let onRemove: () -> Void
    var onConfigureVSCode: () -> Void = {}
    var onRestore: () -> Void = {}
    var onError: (String) -> Void = { _ in }

    // Held as plain value props (not @ObservedObject) so one site's toggle doesn't re-lay-out the
    // whole list; `.equatable()` skips rows whose visible inputs are unchanged.
    @State var domainDraft: String
    @State var domainError = false
    @State var hovering = false
    @State var nodePortDraft: String

    init(
        site: SiteSummary,
        availableVersions: [String],
        canOpen: Bool,
        nodeRunning: Bool,
        share: SiteShareState?,
        framework: PHPFramework,
        apacheInstalled: Bool,
        apacheInstalling: Bool,
        onOpen: @escaping () -> Void,
        onSetVersion: @escaping (String) -> Void,
        onSetSecure: @escaping (Bool) -> Void,
        onSetEngine: @escaping (SiteServerEngine) -> Void,
        onInstallApache: @escaping () -> Void,
        onEditDomain: @escaping (String) throws -> Void,
        onSetNodePort: @escaping (Int?) throws -> Void,
        onOpenLogs: @escaping () -> Void,
        onOpenAPITester: @escaping () -> Void,
        onToggleShare: @escaping (Bool) -> Void,
        onRemove: @escaping () -> Void,
        onConfigureVSCode: @escaping () -> Void = {},
        onRestore: @escaping () -> Void = {},
        onError: @escaping (String) -> Void = { _ in }
    ) {
        self.site = site
        self.availableVersions = availableVersions
        self.canOpen = canOpen
        self.nodeRunning = nodeRunning
        self.share = share
        self.framework = framework
        self.apacheInstalled = apacheInstalled
        self.apacheInstalling = apacheInstalling
        self.onOpen = onOpen
        self.onSetVersion = onSetVersion
        self.onSetSecure = onSetSecure
        self.onSetEngine = onSetEngine
        self.onInstallApache = onInstallApache
        self.onEditDomain = onEditDomain
        self.onSetNodePort = onSetNodePort
        self.onOpenLogs = onOpenLogs
        self.onOpenAPITester = onOpenAPITester
        self.onToggleShare = onToggleShare
        self.onRemove = onRemove
        self.onConfigureVSCode = onConfigureVSCode
        self.onRestore = onRestore
        self.onError = onError
        _domainDraft = State(initialValue: site.domain)
        _nodePortDraft = State(initialValue: site.nodePort.map(String.init) ?? "")
    }

    static func == (a: SiteListRow, b: SiteListRow) -> Bool {
        a.site == b.site
            && a.availableVersions == b.availableVersions
            && a.canOpen == b.canOpen
            && a.nodeRunning == b.nodeRunning
            && a.share == b.share
            && a.framework == b.framework
            && a.apacheInstalled == b.apacheInstalled
            && a.apacheInstalling == b.apacheInstalling
    }

    var body: some View {
        mainRow
            .background(hovering ? KTColor.rowHover : Color.clear)
            .contentShape(Rectangle())
            .onHover { hovering = $0 }
            .onChange(of: site.domain) { new in domainDraft = new; domainError = false }
            .onChange(of: site.nodePort) { new in nodePortDraft = new.map(String.init) ?? "" }
    }

    private var mainRow: some View {
        HStack(spacing: 11) {
            KTIconTile(tint: SiteVisuals.tint(for: site.kind)) {
                KTSiteGlyph(
                    kind: SiteVisuals.kind(for: site.kind),
                    size: 19,
                    color: SiteVisuals.tint(for: site.kind).fg
                )
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(site.name).font(KTType.rowName).foregroundStyle(KTColor.ink).lineLimit(1)
                TextField("domain", text: $domainDraft)
                    .textFieldStyle(.plain)
                    .font(.jbMono(12.5))
                    .foregroundStyle(domainError ? KTColor.danger : KTColor.muted)
                    .lineLimit(1)
                    .onSubmit(commitDomain)
            }
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            .layoutPriority(-1)

            if site.kind == .php {
                KTBadge(text: framework.label, tint: SiteVisuals.tint(for: framework), radius: 8)
                PhpMenu(current: site.phpVersion, versions: availableVersions, onSelect: onSetVersion)
                EngineMenu(
                    current: site.engine,
                    port: site.backendPort,
                    apacheInstalled: apacheInstalled,
                    apacheInstalling: apacheInstalling,
                    onSelect: onSetEngine,
                    onInstallApache: onInstallApache
                )
            } else if site.kind == .node {
                HStack(spacing: 8) {
                    KTBadge(text: SiteVisuals.label(for: site.kind), tint: SiteVisuals.tint(for: site.kind), radius: 8)
                    nodeRoute
                }
            } else {
                KTBadge(text: SiteVisuals.label(for: site.kind), tint: SiteVisuals.tint(for: site.kind), radius: 8)
            }

            if site.kind == .node {
                nodeStatusControl
            } else {
                KTStatusLabel(running: canOpen).frame(width: 78, alignment: .leading)
            }

            KTToggle(isOn: site.secure, action: { onSetSecure(!site.secure) })
                .ktTip("Serve over HTTPS with a locally-trusted certificate")
                .accessibilityLabel("Serve \(site.domain) over HTTPS")

            SiteShareControls(
                shareStarting: share?.starting ?? false,
                shareURL: share?.publicURL,
                shareExpiresAt: share?.expiresAt,
                onToggleShare: onToggleShare
            )

            KTButton(title: "Open", kind: .secondary, action: onOpen)
                .disabled(!openEnabled)
                .ktTip("Open \(site.domain) in your browser")

            SiteActionsMenu(
                site: site,
                canOpen: canOpen,
                onOpenLogs: onOpenLogs,
                onOpenAPITester: onOpenAPITester,
                onRemove: onRemove,
                onConfigureVSCode: onConfigureVSCode,
                onRestore: onRestore
            )
        }
        .padding(.vertical, 13)
        .padding(.horizontal, 16)
    }

    private var openEnabled: Bool {
        site.kind == .node ? (canOpen && nodeRunning) : canOpen
    }

    private func commitDomain() {
        let next = domainDraft.trimmingCharacters(in: .whitespaces).lowercased()
        guard next != site.domain else { domainError = false; return }
        do { try onEditDomain(next); domainError = false }
        catch {
            domainError = true
            domainDraft = site.domain
            onError(error.localizedDescription)
        }
    }
}
