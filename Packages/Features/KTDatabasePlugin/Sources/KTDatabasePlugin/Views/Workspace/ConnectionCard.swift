import KTPlatformContracts
import KTPluginKit
import SwiftUI

struct ConnectionCard: View {
    let profile: ConnectionProfile
    let status: ServerStatus
    let isSelected: Bool
    let engineInstalled: Bool
    let engineRunning: Bool
    let onSelect: () -> Void
    let onOpen: () -> Void
    let onInstallEngine: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: SidebarNode.icon(for: profile.kind))
                .font(.system(size: 14))
                .foregroundStyle(KTEditorTheme.accent)
                .frame(width: 30, height: 30)
                .background(KTEditorTheme.accentSoft, in: RoundedRectangle(cornerRadius: 7))
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(profile.name)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(KTEditorTheme.label)
                        .lineLimit(1)
                    tag
                }
                HStack(spacing: 5) {
                    Circle().fill(statusColor).frame(width: 5, height: 5)
                    Text(profile.subtitle)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(KTEditorTheme.label2)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            Spacer(minLength: 6)
            actionButton
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.accentColor : Color(nsColor: .separatorColor).opacity(0.5), lineWidth: isSelected ? 1.5 : 0.5)
        )
        .contentShape(RoundedRectangle(cornerRadius: 8))
        .onTapGesture(count: 2, perform: onOpen)
        .onTapGesture(perform: onSelect)
    }

    private var tag: some View {
        let local = profile.isManaged || ConnectionProfile.isLoopback(profile.host)
        return Text(local ? "LOCAL" : "REMOTE")
            .font(.system(size: 9.5, weight: .bold, design: .monospaced))
            .foregroundStyle(local ? Color.green : KTEditorTheme.label2)
            .padding(.horizontal, 5)
            .padding(.vertical, 1.5)
            .background(
                (local ? Color.green : KTEditorTheme.label2).opacity(0.14),
                in: RoundedRectangle(cornerRadius: 4)
            )
    }

    @ViewBuilder
    private var actionButton: some View {
        if needsInstall {
            Button(action: onInstallEngine) {
                Text("Cài trong Runtimes ›").font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.plain)
            .foregroundStyle(KTEditorTheme.accent)
        } else {
            Button(engineNeedsStart ? "Bật & mở" : "Mở", action: onOpen)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .keyboardShortcut(isSelected ? .defaultAction : nil)
        }
    }

    private var engine: DatabaseEngine? { profile.isManaged ? profile.kind.engine : nil }
    private var needsInstall: Bool { engine != nil && !engineInstalled }
    private var engineNeedsStart: Bool { engine != nil && engineInstalled && !engineRunning }

    private var statusColor: Color {
        if needsInstall { return KTEditorTheme.Status.stopped }
        switch status {
        case .online: return KTEditorTheme.Status.running
        case .offline: return KTEditorTheme.Status.stopped
        case .connecting: return KTEditorTheme.Status.warning
        }
    }
}

struct NewConnectionCard: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .medium))
                Text("Kết nối mới")
                    .font(.system(size: 12.5, weight: .medium))
            }
            .foregroundStyle(KTEditorTheme.label2)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(Color(nsColor: .separatorColor), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
        )
    }
}
