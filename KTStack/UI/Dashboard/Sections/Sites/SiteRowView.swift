import SwiftUI
import AppKit
import KTStackKit


struct SiteRowView: View {
    let site: Site
    let availableVersions: [String]
    let canOpen: Bool
    let onOpen: () -> Void
    let onRemove: () -> Void
    let onEditDomain: (String) throws -> Void
    let onSetVersion: (String) -> Void
    let onSetSecure: (Bool) -> Void
    let onOpenLogs: () -> Void
    let shareStatus: TunnelStatus
    let onToggleShare: (Bool) -> Void

    @State private var domainDraft: String
    @State private var domainError: String?
    @State private var debugConfigError: String?
    @State private var isHovering = false

    init(site: Site, availableVersions: [String], canOpen: Bool,
         onOpen: @escaping () -> Void, onRemove: @escaping () -> Void,
         onEditDomain: @escaping (String) throws -> Void, onSetVersion: @escaping (String) -> Void,
         onSetSecure: @escaping (Bool) -> Void, onOpenLogs: @escaping () -> Void,
         shareStatus: TunnelStatus = .idle, onToggleShare: @escaping (Bool) -> Void = { _ in }) {
        self.site = site
        self.availableVersions = availableVersions
        self.canOpen = canOpen
        self.onOpen = onOpen
        self.onRemove = onRemove
        self.onEditDomain = onEditDomain
        self.onSetVersion = onSetVersion
        self.onSetSecure = onSetSecure
        self.onOpenLogs = onOpenLogs
        self.shareStatus = shareStatus
        self.onToggleShare = onToggleShare
        _domainDraft = State(initialValue: site.domain)
    }

    var body: some View {
        HStack(spacing: KDSpacing.space3) {
            SiteTypeTile(type: site.type)

            VStack(alignment: .leading, spacing: 2) {
                Text(site.name)
                    .font(KDFont.body.weight(.semibold))
                    .lineLimit(1)
                TextField("domain", text: $domainDraft)
                    .font(KDFont.mono)
                    .textFieldStyle(.plain)
                    .foregroundStyle(domainError == nil ? .secondary : Color.KDStatus.error)
                    .lineLimit(1)
                    .help(domainDraft)
                    .onSubmit(commitDomain)
                if let domainError {
                    Text(domainError).font(KDFont.footnote).foregroundStyle(Color.KDStatus.error)
                }
            }
            .frame(minWidth: 220, idealWidth: 320, maxWidth: .infinity, alignment: .leading)

            SiteRowRuntimeBadge(
                type: site.type,
                phpVersion: site.phpVersion,
                availableVersions: availableVersions,
                onSetVersion: onSetVersion)
            SiteRowStatusBadge(isRunning: canOpen)
            Toggle("Secure", isOn: Binding(get: { site.secure }, set: onSetSecure))
                .toggleStyle(.switch)
                .controlSize(.mini)
                .labelsHidden()
                .help("Serve over HTTPS with a locally-trusted certificate")
                .accessibilityLabel("Serve \(site.domain) over HTTPS")
                .frame(width: 50)

            SiteShareControlView(shareStatus: shareStatus, onToggleShare: onToggleShare)
                .frame(width: 150, alignment: .trailing)

            Button("Open", action: onOpen)
                .disabled(!canOpen)
                .frame(width: 78)

            SiteRowOverflowMenu(
                siteName: site.name,
                type: site.type,
                canOpen: canOpen,
                onOpen: onOpen,
                onRevealInFinder: revealInFinder,
                onOpenTerminal: openTerminal,
                onOpenLogs: onOpenLogs,
                onConfigureVSCode: configureVSCode,
                onRemove: onRemove)
        }
        .padding(.vertical, KDSpacing.space2)
        .padding(.horizontal, KDSpacing.space3)
        .frame(minHeight: 58)
        .background(isHovering ? Color.accentColor.opacity(0.05) : Color.clear)
        .contentShape(Rectangle())
        .onHover { isHovering = $0 }
        .onChange(of: site.domain) { new in domainDraft = new; domainError = nil }
        .alert("Configure VS Code Debug Failed", isPresented: Binding(
            get: { debugConfigError != nil },
            set: { if !$0 { debugConfigError = nil } })) {
                Button("OK", role: .cancel) { debugConfigError = nil }
            } message: {
                Text(debugConfigError ?? "")
            }
    }

    private func commitDomain() {
        let next = domainDraft.trimmingCharacters(in: .whitespaces).lowercased()
        guard next != site.domain else { domainError = nil; return }
        do { try onEditDomain(next); domainError = nil }
        catch { domainError = error.localizedDescription; domainDraft = site.domain }
    }

    private func revealInFinder() {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: site.path)])
    }

    private func openTerminal() {
        let url = URL(fileURLWithPath: site.path)
        let term = URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app")
        NSWorkspace.shared.open([url], withApplicationAt: term,
                                configuration: NSWorkspace.OpenConfiguration())
    }

    private func configureVSCode() {
        do {
            let written = try IDEDebugConfigWriter().writeVSCode(
                projectRoot: URL(fileURLWithPath: site.path),
                docroot: URL(fileURLWithPath: site.docroot))
            NSWorkspace.shared.activateFileViewerSelecting([written])
        } catch {
            debugConfigError = error.localizedDescription
        }
    }
}
