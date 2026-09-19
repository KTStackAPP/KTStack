import KTPlatformContracts
import KTPluginKit
import SwiftUI

struct ConnectionCard: View {
    let profile: ConnectionProfile
    let status: ServerStatus
    let isSelected: Bool
    let engineInstalled: Bool
    let engineRunning: Bool
    var lastUsedDatabase: String? = nil
    var recentDatabases: [String] = []
    let onSelect: () -> Void
    let onOpen: () -> Void
    var onOpenDatabase: ((String) -> Void)? = nil
    let onInstallEngine: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Image(systemName: SidebarNode.icon(for: profile.kind))
                    .font(.title3)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 34, height: 34)
                    .background(Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(profile.displayTitle(lastUsedDatabase: lastUsedDatabase))
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        tag
                    }
                    HStack(spacing: 5) {
                        Circle().fill(statusColor).frame(width: 6, height: 6)
                        Text(profile.displaySubtitle(lastUsedDatabase: lastUsedDatabase))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
                Spacer(minLength: 6)
                actionButton
            }
            if !recentDatabases.isEmpty {
                HStack(spacing: 5) {
                    ForEach(recentDatabases.prefix(3), id: \.self) { db in
                        Button {
                            onOpenDatabase?(db)
                        } label: {
                            HStack(spacing: 3) {
                                Image(systemName: "cylinder")
                                    .font(.caption2)
                                Text(db)
                                    .font(.caption)
                                    .lineLimit(1)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color(nsColor: .controlColor), in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .help("Mở database \(db)")
                    }
                }
                .padding(.leading, 46)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(isSelected ? Color.accentColor : Color(nsColor: .separatorColor).opacity(0.4), lineWidth: isSelected ? 1.5 : 0.5)
        )
        .shadow(color: isSelected ? Color.accentColor.opacity(0.12) : Color.black.opacity(0.03), radius: isSelected ? 4 : 2, y: 1)
        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .onTapGesture(count: 2, perform: onOpen)
        .onTapGesture(perform: onSelect)
    }

    private var tag: some View {
        let local = profile.isManaged || ConnectionProfile.isLoopback(profile.host)
        return Text(local ? "LOCAL" : "REMOTE")
            .font(.caption2.bold())
            .foregroundStyle(local ? Color.green : .secondary)
            .padding(.horizontal, 5)
            .padding(.vertical, 1.5)
            .background(
                (local ? Color.green : Color.secondary).opacity(0.12),
                in: RoundedRectangle(cornerRadius: 4, style: .continuous)
            )
    }

    @ViewBuilder
    private var actionButton: some View {
        if needsInstall {
            Button(action: onInstallEngine) {
                Text("Install ›")
                    .font(.footnote.weight(.medium))
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.accentColor)
        } else {
            Button(engineNeedsStart ? "Start & Open" : "Open", action: onOpen)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .keyboardShortcut(isSelected ? .defaultAction : nil)
        }
    }

    private var engine: DatabaseEngine? { profile.isManaged ? profile.kind.engine : nil }
    private var needsInstall: Bool { engine != nil && !engineInstalled }
    private var engineNeedsStart: Bool { engine != nil && engineInstalled && !engineRunning }

    private var statusColor: Color {
        if needsInstall { return .secondary }
        switch status {
        case .online: return .green
        case .offline: return .secondary
        case .connecting: return .orange
        }
    }
}
