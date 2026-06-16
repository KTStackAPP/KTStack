import SwiftUI
import KDWarmKit

struct ServiceRowView: View {
    let snapshot: ServiceSnapshot

    let canToggle: Bool
    let onToggle: () -> Void
    let onRestart: () -> Void
    let onOpenLogs: () -> Void
    var onInstall: () -> Void = {}
    var onCancelInstall: () -> Void = {}

    var onResetData: () -> Void = {}

    @State private var showResetConfirm = false

   
    private var canResetData: Bool { snapshot.kind == .mongodb && snapshot.status == .error }

    var body: some View {
        HStack(spacing: KDSpacing.space3) {
            Image(systemName: snapshot.symbolName)
                .frame(width: 24)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 1) {
                Text(snapshot.displayName).font(KDFont.body).fontWeight(.medium)
                Text(secondaryText)
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            Spacer(minLength: KDSpacing.space2)
            if let metrics = snapshot.metricsText {
                Text(metrics)
                    .font(KDFont.footnote)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            StatusPill(snapshot.status, text: pillText)

            restartButton

            trailingControl

            overflowMenu
        }
        .padding(.vertical, KDSpacing.space3)
        .padding(.horizontal, KDSpacing.space4)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(snapshot.displayName), \(snapshot.status.label), \(pillText)")
        .confirmationDialog("Reset \(snapshot.displayName) data?", isPresented: $showResetConfirm) {
            Button("Reset \(snapshot.displayName) data", role: .destructive, action: onResetData)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently deletes \(snapshot.displayName)'s stored data, then restarts it from "
                + "an empty datastore. Use this only to recover a service stuck after an unclean shutdown.")
        }
    }


    private var canRestart: Bool {
        canToggle && snapshot.isInstalled && snapshot.status == .running
    }

    private var restartButton: some View {
        Button(action: onRestart) {
            Image(systemName: "arrow.clockwise")
        }
        .buttonStyle(.borderless)
        .foregroundStyle(.secondary)
        .disabled(!canRestart)
        .help("Restart \(snapshot.displayName)")
        .accessibilityLabel("Restart \(snapshot.displayName)")
    }

    @ViewBuilder
    private var trailingControl: some View {
        if let fraction = snapshot.downloadFraction {
            HStack(spacing: KDSpacing.space1) {
                ProgressView(value: fraction).frame(width: 56)
                Button { onCancelInstall() } label: { Image(systemName: "xmark.circle") }
                    .buttonStyle(.borderless)
            }
        } else if !snapshot.isInstalled && snapshot.installable {
            Button("Install", action: onInstall).controlSize(.small)
        } else if snapshot.isBusy {
            ProgressView().controlSize(.small).frame(width: 32)
        } else {
            Toggle("", isOn: toggleBinding)
                .toggleStyle(.switch).controlSize(.mini).labelsHidden()
                .disabled(!canToggle || !snapshot.isInstalled)
        }
    }

    private var toggleBinding: Binding<Bool> {
        Binding(get: { snapshot.status == .running }, set: { _ in onToggle() })
    }

    private var pillText: String {
        guard snapshot.isInstalled else { return "Not installed" }
        return snapshot.status == .warning ? "Degraded" : snapshot.status.label
    }

    private var secondaryText: String {
        if !snapshot.isInstalled {
            return snapshot.installable ? "Not installed — click Install to download" : "Not available in this build yet"
        }
        if let error = snapshot.errorMessage { return error }
        return snapshot.kind.subtitle
    }

    private var overflowMenu: some View {
        Menu {
            Button("Open Logs", systemImage: "text.alignleft", action: onOpenLogs)
                .disabled(snapshot.kind == .dnsmasq)
            if canResetData {
                Divider()
                Button("Reset Data…", systemImage: "trash", role: .destructive) { showResetConfirm = true }
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .frame(width: 28)
    }
}

private extension ServiceKind {

    var subtitle: String {
        switch self {
        case .nginx:    return "Reverse proxy · ports 80, 443"
        case .phpFpm:   return "FastCGI pools · managed with web server"
        case .dnsmasq:  return "*.test resolver · port 53 · privileged helper"
        case .mysql:    return "Database · port 3306"
        case .postgres: return "Database · port 5432"
        case .redis:    return "Cache · port 6379"
        case .mongodb:  return "Document DB · port 27017"
        case .mailpit:  return "Mail catcher · SMTP 1025 · web 8025"
        }
    }
}
