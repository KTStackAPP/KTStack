import KTPluginKit
import SwiftUI

struct WorkspaceStatusPill: View {
    @ObservedObject var session: WorkspaceSession
    @ObservedObject var shell: DatabaseV2ViewModel
    @ObservedObject var store: WorkspaceStore

    init(session: WorkspaceSession) {
        self.session = session
        self._shell = ObservedObject(wrappedValue: session.shell)
        self._store = ObservedObject(wrappedValue: session.store)
    }

    private var currentDatabase: String {
        store.activeDatabase ?? shell.selectedDatabase ?? "—"
    }

    private var isManaged: Bool {
        shell.activeProfile?.isManaged ?? false
    }

    private var engineVersionText: String {
        let engine: String
        switch shell.connectionKind {
        case .mysql: engine = "MySQL"
        case .postgres: engine = "PostgreSQL"
        case .sqlite: engine = "SQLite"
        case .mongodb: engine = "MongoDB"
        case nil: engine = "Database"
        }
        if let version = shell.serverVersion, !version.isEmpty {
            return "\(engine) \(version)"
        }
        return engine
    }

    var body: some View {
        if shell.isConnected {
            pillContent
        }
    }

    private var pillContent: some View {
        HStack(spacing: 8) {
            tagBadge
            engineLabel
            separator
            databaseMenu
            separator
            lockIcon
            if let ms = shell.latencyMs {
                separator
                latencyLabel(ms)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .modifier(LiquidGlassCapsuleModifier())
        .fixedSize()
    }

    private var tagBadge: some View {
        Text(isManaged ? "LOCAL" : "REMOTE")
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .foregroundStyle(isManaged ? Color.green : Color.blue)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                (isManaged ? Color.green : Color.blue).opacity(0.14),
                in: RoundedRectangle(cornerRadius: 4, style: .continuous)
            )
            .fixedSize()
    }

    private var engineLabel: some View {
        Text(engineVersionText)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.primary)
            .fixedSize()
    }

    private var separator: some View {
        Rectangle()
            .fill(Color(nsColor: .separatorColor))
            .frame(width: 1, height: 12)
    }

    private var databaseMenu: some View {
        Menu {
            ForEach(shell.databases) { db in
                Button {
                    session.selectDatabase(db.name)
                } label: {
                    if db.name == currentDatabase {
                        Label(db.name, systemImage: "checkmark")
                    } else {
                        Text(db.name)
                    }
                }
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "cylinder.split.1x2")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.accentColor)
                Text(currentDatabase)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private var lockIcon: some View {
        Image(systemName: shell.connectionIsReadOnly ? "lock.fill" : "lock.open")
            .font(.system(size: 11))
            .foregroundStyle(shell.connectionIsReadOnly ? Color.orange : Color(nsColor: .tertiaryLabelColor))
            .help(shell.connectionIsReadOnly ? "Read-only connection" : "Read-write connection")
    }

    private func latencyLabel(_ ms: Int) -> some View {
        Text(ms <= 0 ? "<1ms" : "\(ms)ms")
            .font(.system(size: 10, design: .monospaced))
            .foregroundStyle(.secondary)
            .fixedSize()
    }
}

struct LiquidGlassCapsuleModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(macOS 27, *) {
            content
                .glassEffect(.regular.interactive(), in: .capsule)
        } else {
            content
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().stroke(Color(nsColor: .separatorColor).opacity(0.4), lineWidth: 0.5))
        }
    }
}
