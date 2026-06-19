import SwiftUI
import AppKit
import KTStackKit

struct SitesHeaderView: View {
    let siteCount: Int
    let serverStatus: ServiceStatus
    let isRunning: Bool
    let isBusy: Bool
    let onToggleServer: () -> Void
    let onScan: () -> Void
    let onImport: () -> Void
    let onAddExisting: () -> Void
    let onNewSite: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: KDSpacing.space2) {
            HStack(spacing: KDSpacing.space2) {
                Text("Sites")
                    .font(.largeTitle.weight(.bold))
                Text("\(siteCount) sites")
                    .font(KDFont.footnote.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.vertical, KDSpacing.space1)
                    .padding(.horizontal, KDSpacing.space2)
                    .background(Capsule().fill(Color(nsColor: .controlColor)))
                Spacer()
                Button(action: onScan) {
                    Label("Scan", systemImage: "arrow.triangle.2.circlepath")
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                Button(action: onImport) {
                    Label("Import", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                HStack(spacing: 0) {
                    Button(action: onNewSite) {
                        Label("New Site", systemImage: "plus")
                    }
                    .keyboardShortcut("n", modifiers: .command)
                    Divider()
                        .frame(height: 18)
                    Menu {
                        Button("Add Existing Folder", systemImage: "folder.badge.plus", action: onAddExisting)
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.caption.weight(.semibold))
                            .frame(width: 24)
                    }
                    .menuIndicator(.hidden)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .clipShape(RoundedRectangle(cornerRadius: KDRadius.control))
            }
            HStack(spacing: KDSpacing.space2) {
                SitesServerStatusPill(status: displayStatus)
                Button(isRunning ? "Stop Server" : "Start Server", action: onToggleServer)
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                    .disabled(isBusy)
            }
        }
        .padding(.horizontal, KDSpacing.space4)
        .padding(.vertical, KDSpacing.space3)
    }

    private var displayStatus: ServiceStatus {
        if serverStatus == .starting || serverStatus == .error || serverStatus == .warning {
            return serverStatus
        }
        return isRunning ? .running : .stopped
    }
}

struct SitesSearchStrip: View {
    @Binding var text: String

    var body: some View {
        HStack(spacing: KDSpacing.space2) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search sites by name or domain...", text: $text)
                .textFieldStyle(.plain)
                .font(KDFont.body)
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .help("Clear search")
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, KDSpacing.space3)
        .frame(height: 40)
        .background(Color(nsColor: .textBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: KDRadius.control))
        .overlay(
            RoundedRectangle(cornerRadius: KDRadius.control)
                .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 0.5))
    }
}

struct SitesListSurface<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: KDRadius.card))
            .overlay(
                RoundedRectangle(cornerRadius: KDRadius.card)
                    .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 0.5))
    }
}

struct SiteTypeTile: View {
    let type: SiteType

    var body: some View {
        Image(systemName: type.symbolName)
            .font(.system(size: 17, weight: .medium))
            .foregroundStyle(tint)
            .frame(width: 36, height: 36)
            .background(
                RoundedRectangle(cornerRadius: KDRadius.control)
                    .fill(tint.opacity(0.12)))
            .accessibilityLabel(type.label)
    }

    private var tint: Color {
        switch type {
        case .php: return Color.KDStatus.starting
        case .staticSite: return Color.KDStatus.warning
        case .node: return Color.KDStatus.info
        }
    }
}

private struct SitesServerStatusPill: View {
    let status: ServiceStatus

    var body: some View {
        HStack(spacing: KDSpacing.space1) {
            Image(systemName: status.symbolName)
            Text("Server: \(status.label)")
        }
        .font(KDFont.footnote.weight(.medium))
        .foregroundStyle(status.color)
        .padding(.vertical, KDSpacing.space1)
        .padding(.horizontal, KDSpacing.space2)
        .background(Capsule().fill(status.color.opacity(0.14)))
        .accessibilityLabel("Server \(status.label)")
    }
}
