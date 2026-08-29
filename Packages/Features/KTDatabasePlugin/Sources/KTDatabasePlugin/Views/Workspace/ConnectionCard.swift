import KTPlatformContracts
import KTPluginKit
import SwiftUI

/// Card một kết nối trên trang kết nối: tile engine, tên + tag LOCAL/REMOTE, host mono, chân card
/// (chấm trạng thái + nút mở). Managed engine đổi nút theo cài/chạy.
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
        VStack(alignment: .leading, spacing: 10) {
            header
            Text(profile.subtitle)
                .font(.jbMono(11))
                .foregroundStyle(KTEditorTheme.label2)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 0)
            footer
        }
        .padding(14)
        .frame(height: 128, alignment: .topLeading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(KTEditorTheme.content2, in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? KTEditorTheme.accent : KTEditorTheme.separator, lineWidth: isSelected ? 1.5 : 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(KTEditorTheme.accentSoft, lineWidth: isSelected ? 4 : 0)
        )
        .contentShape(RoundedRectangle(cornerRadius: 10))
        .onTapGesture(count: 2, perform: onOpen)
        .onTapGesture(perform: onSelect)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: SidebarNode.icon(for: profile.kind))
                .font(.system(size: 15))
                .foregroundStyle(KTEditorTheme.accent)
                .frame(width: 30, height: 30)
                .background(KTEditorTheme.accentSoft, in: RoundedRectangle(cornerRadius: 7))
            VStack(alignment: .leading, spacing: 2) {
                Text(profile.name)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(KTEditorTheme.label)
                    .lineLimit(1)
                tag
            }
            Spacer(minLength: 0)
        }
    }

    private var tag: some View {
        let local = profile.isManaged || ConnectionProfile.isLoopback(profile.host)
        return Text(local ? "LOCAL" : "REMOTE")
            .font(.jbMono(9, .bold))
            .foregroundStyle(local ? KTEditorTheme.Status.running : KTEditorTheme.label2)
            .padding(.horizontal, 5)
            .padding(.vertical, 1.5)
            .background(
                (local ? KTEditorTheme.Status.running : KTEditorTheme.label2).opacity(0.14),
                in: RoundedRectangle(cornerRadius: 4)
            )
    }

    private var footer: some View {
        HStack(spacing: 8) {
            HStack(spacing: 5) {
                Circle().fill(statusColor).frame(width: 6, height: 6)
                Text(statusText)
                    .font(.system(size: 11))
                    .foregroundStyle(KTEditorTheme.label2)
            }
            Spacer(minLength: 0)
            actionButton
        }
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
            Button(action: onOpen) {
                Text(engineNeedsStart ? "Bật & mở" : "Mở")
                    .font(.system(size: 11, weight: .semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
            .foregroundStyle(KTEditorTheme.onAccent)
            .background(KTEditorTheme.accent, in: Capsule())
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

    private var statusText: String {
        if needsInstall { return "Chưa cài" }
        switch status {
        case .online: return "Đang chạy"
        case .offline: return "Chưa chạy"
        case .connecting: return "Đang kiểm tra…"
        }
    }
}

/// Card nét đứt "Kết nối mới".
struct NewConnectionCard: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .medium))
                Text("Kết nối mới")
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(KTEditorTheme.label2)
            .frame(maxWidth: .infinity)
            .frame(height: 128)
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                .foregroundStyle(KTEditorTheme.separatorStrong)
        )
    }
}
