import KTPlatformContracts
import KTPluginKit
import SwiftUI

// Row DB/cache engine trong tab Services: run/stop + đổi version đã cài. Download/uninstall ở Runtimes.
struct DatabaseServiceRow: View, Equatable {
    let state: ServiceState
    let installedVersions: [String]
    let activeVersion: String?
    let vm: ServicesViewModel
    let onToggle: () -> Void
    let onRestart: () -> Void
    let onOpenLogs: () -> Void
    let onSetActive: (String) -> Void
    let onManageInRuntimes: () -> Void

    @State private var hovering = false

    static func == (a: DatabaseServiceRow, b: DatabaseServiceRow) -> Bool {
        a.state.id == b.state.id
            && a.state.health == b.state.health
            && a.state.detail == b.state.detail
            && a.state.isInstalled == b.state.isInstalled
            && a.state.isBusy == b.state.isBusy
            && a.state.errorMessage == b.state.errorMessage
            && a.activeVersion == b.activeVersion
            && a.installedVersions == b.installedVersions
    }

    private var isRunning: Bool { state.health == .running }

    var body: some View {
        HStack(spacing: 14) {
            KTIconTile(tint: state.id.tint, size: 40, radius: 11) {
                Image(systemName: state.symbolName).font(.system(size: 18, weight: .medium))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(state.displayName).font(KTType.rowName).foregroundStyle(KTColor.ink)
                Text(secondaryText).font(KTType.sub).foregroundStyle(KTColor.muted).lineLimit(1).truncationMode(.tail)
            }
            Spacer(minLength: 8)
            if state.isInstalled {
                versionDropdown
                ServiceMetricsText(vm: vm, id: state.id)
                statusLabel.frame(width: 104, alignment: .leading)
                restartButton
                trailingControl
                overflowMenu
            } else {
                KTButton(title: "Runtimes", kind: .secondary, action: onManageInRuntimes)
            }
        }
        .padding(.vertical, 15)
        .padding(.horizontal, 18)
        .background(hovering ? KTColor.rowHover : Color.clear)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
    }

    @ViewBuilder
    private var versionDropdown: some View {
        // KTDropdown chỉ chứa version; đổi bị chặn khi engine đang chạy vì setActiveVersion từ chối.
        KTDropdown(
            width: 150,
            options: installedVersions.map { version in
                KTDropdownOption(label: version, active: version == activeVersion) { onSetActive(version) }
            }
        ) {
            KTDropdownChevronLabel(text: activeVersion ?? "—")
        }
        .fixedSize()
        .disabled(isRunning || state.isBusy || installedVersions.isEmpty)
        .opacity(isRunning || state.isBusy ? 0.5 : 1)
        .help(isRunning ? "Stop \(state.displayName) to switch version" : "")
    }

    @ViewBuilder
    private var trailingControl: some View {
        if state.isBusy {
            ProgressView().controlSize(.small).frame(width: 40)
        } else {
            KTToggle(isOn: isRunning, action: onToggle)
        }
    }

    private var restartButton: some View {
        Button(action: onRestart) {
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(KTColor.ink3)
                .frame(width: 34, height: 32)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(.white))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(KTColor.btnBorder, lineWidth: 0.5))
        }
        .buttonStyle(.plain)
        .disabled(!canRestart)
        .opacity(canRestart ? 1 : 0.4)
        .help("Restart \(state.displayName)")
    }

    private var overflowMenu: some View {
        Menu {
            Button("Open Logs", systemImage: "text.alignleft", action: onOpenLogs)
            Button("Manage in Runtimes…", systemImage: "cube", action: onManageInRuntimes)
        } label: {
            Image(systemName: "ellipsis").font(.system(size: 15, weight: .regular))
                .foregroundStyle(KTColor.muted).frame(width: 28, height: 30).contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton).menuIndicator(.hidden).frame(width: 28)
    }

    private var canRestart: Bool {
        state.isInstalled && isRunning && !state.isBusy
    }

    private var statusLabel: some View {
        HStack(spacing: 7) {
            KTDot(color: dotColor)
            Text(pillText).font(.jbMono(13, .medium)).foregroundStyle(textColor)
        }
    }

    private var pillText: String {
        state.health == .warning ? "Degraded" : state.health.label
    }

    private var secondaryText: String {
        if !state.isInstalled { return "Not installed. Install in Runtimes." }
        if let error = state.errorMessage { return error }
        return state.id.subtitle
    }

    private var dotColor: Color {
        switch state.health {
        case .running: KTColor.runDot
        case .error: KTColor.danger
        case .warning: Color(hex: 0xFF9F0A)
        case .starting: KTColor.accent
        default: KTColor.stopDot
        }
    }

    private var textColor: Color {
        switch state.health {
        case .running: KTColor.ink
        case .error: KTColor.danger
        case .warning: Color(hex: 0xFF9F0A)
        default: KTColor.stopText
        }
    }
}
