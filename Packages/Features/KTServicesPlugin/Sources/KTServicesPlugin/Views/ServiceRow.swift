import KTPlatformContracts
import KTPluginKit
import SwiftUI

struct ServiceRow: View, Equatable {
    let state: ServiceState
    let canToggle: Bool
    let vm: ServicesViewModel
    let onToggle: () -> Void
    let onRestart: () -> Void
    let onOpenLogs: () -> Void
    var onInstall: () -> Void = {}
    var onCancelInstall: () -> Void = {}
    var onResetData: () -> Void = {}
    var onEditConfig: (() -> Void)? = nil

    @State private var hovering = false
    @State private var showResetConfirm = false

    // Bỏ qua re-render khi chỉ cpu/mem đổi (~0.9s): metric tick nếu không sẽ layout lại row lúc đang
    // toggle làm knob giật. Metrics live cập nhật qua subview ServiceMetricsText tách riêng.
    static func == (a: ServiceRow, b: ServiceRow) -> Bool {
        a.canToggle == b.canToggle
            && a.state.id == b.state.id
            && a.state.health == b.state.health
            && a.state.detail == b.state.detail
            && a.state.isInstalled == b.state.isInstalled
            && a.state.isBusy == b.state.isBusy
            && a.state.errorMessage == b.state.errorMessage
            && a.state.installable == b.state.installable
            && a.state.downloadFraction == b.state.downloadFraction
    }

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
            ServiceMetricsText(vm: vm, id: state.id)
            statusLabel.frame(width: 104, alignment: .leading)
            restartButton
            trailingControl
            overflowMenu
        }
        .padding(.vertical, 15)
        .padding(.horizontal, 18)
        .background(hovering ? KTColor.rowHover : Color.clear)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .confirmationDialog("Reset \(state.displayName) data?", isPresented: $showResetConfirm) {
            Button("Reset \(state.displayName) data", role: .destructive, action: onResetData)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently deletes \(state.displayName)'s stored data, then restarts it from an empty datastore.")
        }
    }

    private var statusLabel: some View {
        HStack(spacing: 7) {
            KTDot(color: dotColor)
            Text(pillText).font(.jbMono(13, .medium)).foregroundStyle(textColor)
        }
    }

    @ViewBuilder
    private var trailingControl: some View {
        if let fraction = state.downloadFraction {
            HStack(spacing: 6) {
                ProgressView(value: fraction).frame(width: 56)
                Button { onCancelInstall() } label: {
                    Image(systemName: "xmark.circle").foregroundStyle(KTColor.muted)
                        .frame(width: 28, height: 28).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        } else if !state.isInstalled, state.installable {
            KTButton(title: "Install", kind: .primary, action: onInstall)
        } else if state.isBusy {
            ProgressView().controlSize(.small).frame(width: 40)
        } else {
            KTToggle(isOn: state.health == .running, action: onToggle)
                .disabled(!canToggle || !state.isInstalled)
                .opacity(canToggle && state.isInstalled ? 1 : 0.45)
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
                .disabled(state.id == .dnsmasq)
            if state.id == .nginx, let editConfig = onEditConfig {
                Button("Edit nginx config…", systemImage: "doc.text", action: editConfig)
            }
            if state.id == .mongodb, state.health == .error {
                Divider()
                Button("Reset Data…", systemImage: "trash", role: .destructive) { showResetConfirm = true }
            }
        } label: {
            Image(systemName: "ellipsis").font(.system(size: 15, weight: .regular))
                .foregroundStyle(KTColor.muted).frame(width: 28, height: 30).contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton).menuIndicator(.hidden).frame(width: 28)
    }

    private var canRestart: Bool {
        canToggle && state.isInstalled && state.health == .running
    }

    private var pillText: String {
        guard state.isInstalled else { return "Not installed" }
        return state.health == .warning ? "Degraded" : state.health.label
    }

    private var secondaryText: String {
        if !state.isInstalled {
            return state.installable ? "Not installed. Click Install to download." : "Not available in this build yet"
        }
        if let error = state.errorMessage { return error }
        return state.id.subtitle
    }

    private var dotColor: Color {
        guard state.isInstalled else { return KTColor.stopDot }
        switch state.health {
        case .running: return KTColor.runDot
        case .error: return KTColor.danger
        case .warning: return Color(hex: 0xFF9F0A)
        case .starting: return KTColor.accent
        default: return KTColor.stopDot
        }
    }

    private var textColor: Color {
        guard state.isInstalled else { return KTColor.stopText }
        switch state.health {
        case .running: return KTColor.ink
        case .error: return KTColor.danger
        case .warning: return Color(hex: 0xFF9F0A)
        default: return KTColor.stopText
        }
    }
}

// Quan sát vm riêng để refresh cpu/mem (~0.9s) chỉ render lại text này, không phải row cha
// (Equatable bỏ qua thay đổi chỉ-metric nên toggle mượt).
struct ServiceMetricsText: View {
    @ObservedObject var vm: ServicesViewModel
    let id: ServiceID

    var body: some View {
        if let metrics = vm.metricsText(id) {
            Text(metrics).font(.jbMono(12)).monospacedDigit().foregroundStyle(KTColor.muted)
        }
    }
}
