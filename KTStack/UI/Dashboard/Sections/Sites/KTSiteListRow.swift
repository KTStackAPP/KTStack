import SwiftUI
import KTStackKit

struct KTSiteListRow: View {
    let site: Site
    let availableVersions: [String]
    let canOpen: Bool
    let isSharing: Bool
    let onOpen: () -> Void
    let onSetVersion: (String) -> Void
    let onSetSecure: (Bool) -> Void
    let onEditDomain: (String) throws -> Void
    let onOpenLogs: () -> Void
    let onToggleShare: (Bool) -> Void
    let onRemove: () -> Void
    var onError: (String) -> Void = { _ in }

    @State private var domainDraft: String
    @State private var domainError = false
    @State private var hovering = false

    init(site: Site, availableVersions: [String], canOpen: Bool, isSharing: Bool,
         onOpen: @escaping () -> Void, onSetVersion: @escaping (String) -> Void,
         onSetSecure: @escaping (Bool) -> Void, onEditDomain: @escaping (String) throws -> Void,
         onOpenLogs: @escaping () -> Void, onToggleShare: @escaping (Bool) -> Void,
         onRemove: @escaping () -> Void, onError: @escaping (String) -> Void = { _ in }) {
        self.site = site
        self.availableVersions = availableVersions
        self.canOpen = canOpen
        self.isSharing = isSharing
        self.onOpen = onOpen
        self.onSetVersion = onSetVersion
        self.onSetSecure = onSetSecure
        self.onEditDomain = onEditDomain
        self.onOpenLogs = onOpenLogs
        self.onToggleShare = onToggleShare
        self.onRemove = onRemove
        self.onError = onError
        _domainDraft = State(initialValue: site.domain)
    }

    var body: some View {
        HStack(spacing: 14) {
            KTIconTile(tint: KTSiteVisuals.tint(for: site.type)) {
                KTSiteGlyph(kind: KTSiteVisuals.kind(for: site.type), size: 19,
                            color: KTSiteVisuals.tint(for: site.type).fg)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(site.name).font(KTType.rowName).foregroundStyle(KTColor.ink).lineLimit(1)
                TextField("domain", text: $domainDraft)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12.5, design: .monospaced))
                    .foregroundStyle(domainError ? KTColor.danger : KTColor.muted)
                    .lineLimit(1)
                    .onSubmit(commitDomain)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if site.type == .php {
                KTPhpMenu(current: site.phpVersion, versions: availableVersions, onSelect: onSetVersion)
            } else {
                KTBadge(text: site.type.label, tint: KTSiteVisuals.tint(for: site.type), radius: 8)
            }

            KTStatusLabel(running: canOpen).frame(width: 92, alignment: .leading)

            KTToggle(isOn: site.secure, action: { onSetSecure(!site.secure) })
                .help("Serve over HTTPS with a locally-trusted certificate")
                .accessibilityLabel("Serve \(site.domain) over HTTPS")

            KTButton(title: "Open", kind: .secondary, action: onOpen)
                .disabled(!canOpen)

            KTSiteActionsMenu(site: site, canOpen: canOpen, isSharing: isSharing,
                              onOpenLogs: onOpenLogs, onToggleShare: onToggleShare,
                              onRemove: onRemove, onError: onError)
        }
        .padding(.vertical, 13)
        .padding(.horizontal, 16)
        .background(hovering ? KTColor.rowHover : Color.clear)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onChange(of: site.domain) { new in domainDraft = new; domainError = false }
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
