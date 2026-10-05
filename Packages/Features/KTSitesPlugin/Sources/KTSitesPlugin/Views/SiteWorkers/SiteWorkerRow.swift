import KTPlatformContracts
import KTPluginKit
import KTStackCore
import SwiftUI

struct SiteWorkerRow: View {
    struct Actions {
        let start: () -> Void
        let stop: () -> Void
        let restart: () -> Void
        let logs: () -> Void
        let edit: () -> Void
        let remove: () -> Void
    }

    let worker: SiteWorker
    let status: SiteWorkerStatus
    let actions: Actions

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            KTDot(color: SiteWorkerVisuals.color(for: status.state))
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(worker.name).font(.jbMono(12.5, .medium)).foregroundStyle(KTColor.ink)
                    Text(SiteWorkerVisuals.detail(for: status)).font(.jbMono(11.5)).foregroundStyle(KTColor.muted)
                }
                Text(worker.command).font(.jbMono(11.5)).foregroundStyle(KTColor.ink2)
                    .lineLimit(1).truncationMode(.middle)
                    .help(worker.command)
            }
            Spacer(minLength: 8)
            controls
        }
        .padding(.vertical, 8).padding(.horizontal, 12)
        .background(RoundedRectangle(cornerRadius: 8).fill(KTColor.fieldBg))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(KTColor.sep, lineWidth: 0.5))
    }

    private var controls: some View {
        HStack(spacing: 6) {
            if worker.enabled {
                iconButton("stop.fill", "Stop \(worker.name)", actions.stop)
                iconButton("arrow.clockwise", "Restart \(worker.name)", actions.restart)
                    .disabled(status.state == .waitingForServer)
            } else {
                iconButton("play.fill", "Start \(worker.name)", actions.start)
            }
            iconButton("text.alignleft", "Show \(worker.name) logs", actions.logs)
            Menu {
                Button("Edit…", action: actions.edit)
                Button("Remove", role: .destructive, action: actions.remove)
            } label: {
                Image(systemName: "ellipsis.circle").foregroundStyle(KTColor.muted)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .accessibilityLabel("More actions for \(worker.name)")
        }
    }

    private func iconButton(_ symbol: String, _ label: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 11, weight: .semibold)).foregroundStyle(KTColor.ink2)
                .frame(width: 22, height: 22)
        }
        .buttonStyle(.plain)
        .help(label)
        .accessibilityLabel(label)
    }
}

enum SiteWorkerVisuals {
    static func color(for state: SiteWorkerRunState) -> Color {
        switch state {
        case .running: Color.KDStatus.running
        case .starting, .backoff: Color.KDStatus.warning
        case .crashed: Color.KDStatus.error
        case .stopped, .waitingForServer: Color.KDStatus.stopped
        }
    }

    static func detail(for status: SiteWorkerStatus) -> String {
        switch status.state {
        case .backoff:
            guard let next = status.nextAttemptAt else { return status.state.label }
            let seconds = max(0, Int(next.timeIntervalSinceNow.rounded(.up)))
            return "Restarting in \(seconds)s"
        case .crashed:
            return status.lastExitStatus.map { "Crashed (exit \($0))" } ?? status.state.label
        case .running where status.restarts > 0:
            return "Running · restarted \(status.restarts)×"
        default:
            return status.state.label
        }
    }
}
