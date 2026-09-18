import KTPluginKit
import SwiftUI

struct WorkspaceToolbar: View {
    @ObservedObject var session: WorkspaceSession
    @ObservedObject var store: WorkspaceStore

    init(session: WorkspaceSession) {
        self.session = session
        self._store = ObservedObject(wrappedValue: session.store)
    }

    var body: some View {
        HStack(spacing: 8) {
            leftCluster
            Spacer(minLength: 12)
            if session.shell.isConnected {
                WorkspaceHeaderDatabaseScopeBar(session: session)
            }
            Spacer(minLength: 12)
            rightCluster
        }
        .padding(.horizontal, 12)
        .frame(height: 32)
    }

    private var leftCluster: some View {
        HStack(spacing: 4) {
            Button("Sidebar", systemImage: "sidebar.left") {
                store.sidebarVisible.toggle()
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .foregroundStyle(store.sidebarVisible ? KTEditorTheme.accent : KTEditorTheme.label2)
            .help("Toggle Sidebar (⌘0)")

            if let active = store.activeSession {
                Button("Back", systemImage: "chevron.left") {
                    active.vm.goBack()
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .disabled(!active.vm.canGoBack)
                .help("Back")

                Button("Forward", systemImage: "chevron.right") {
                    active.vm.goForward()
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .disabled(!active.vm.canGoForward)
                .help("Forward")

                Button("Reload", systemImage: "arrow.clockwise") {
                    store.refreshActive()
                }
                .labelStyle(.iconOnly)
                .buttonStyle(.borderless)
                .help("Reload (⌘R)")
            }
        }
    }

    private var rightCluster: some View {
        HStack(spacing: 6) {
            Button("Filter", systemImage: "magnifyingglass") {
                store.focusFilter()
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .help("Filter Tables (⌘F)")

            Button("Query", systemImage: "plus") {
                store.openQueryForActive()
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .help("New Query Tab (⌘T)")

            WorkspaceWindowButtons(workspace: store)
            WorkspaceConnectionMenu(workspace: store)

            Button("Inspector", systemImage: "sidebar.right") {
                store.inspectorVisible.toggle()
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .foregroundStyle(store.inspectorVisible ? KTEditorTheme.accent : KTEditorTheme.label2)
            .help("Toggle Inspector (⌘⌥I)")
        }
    }
}

struct WorkspaceHeaderDatabaseScopeBar: View {
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

    private var engineName: String {
        switch shell.connectionKind {
        case .mysql: return "MySQL"
        case .postgres: return "PostgreSQL"
        case .sqlite: return "SQLite"
        case .mongodb: return "MongoDB"
        case nil: return "Database"
        }
    }

    private var isManaged: Bool {
        shell.activeProfile?.isManaged ?? false
    }

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 5) {
                Circle()
                    .fill(isManaged ? Color.green : Color.blue)
                    .frame(width: 6, height: 6)
                Text(engineName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color(nsColor: .quaternaryLabelColor).opacity(0.35), in: RoundedRectangle(cornerRadius: 5, style: .continuous))

            Rectangle()
                .fill(Color(nsColor: .separatorColor))
                .frame(width: 1, height: 12)

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
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.secondary)
                }
                .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            if shell.connectionIsReadOnly {
                Rectangle()
                    .fill(Color(nsColor: .separatorColor))
                    .frame(width: 1, height: 12)
                Image(systemName: "lock.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.orange)
                    .help("Read-only connection")
            }

            if let ms = shell.latencyMs {
                Rectangle()
                    .fill(Color(nsColor: .separatorColor))
                    .frame(width: 1, height: 12)
                Text("\(ms) ms")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.55), lineWidth: 0.5)
        )
    }
}

private struct WorkspaceConnectionMenu: View {
    @ObservedObject var workspace: WorkspaceStore

    var body: some View {
        Menu {
            Button("Disconnect") { workspace.requestDisconnect() }
                .disabled(workspace.selectedProfileID == nil)
            Button("Open Another Connection…") { workspace.requestOpenConnection() }
        } label: {
            Label("Connection Options", systemImage: "ellipsis.circle")
                .labelStyle(.iconOnly)
                .foregroundStyle(KTEditorTheme.label2)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }
}

private struct WorkspaceWindowButtons: View {
    @ObservedObject var workspace: WorkspaceStore

    var body: some View {
        HStack(spacing: 4) {
            Button("Backups", systemImage: "archivebox") {
                workspace.requestBackups()
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .disabled(workspace.selectedProfileID == nil)
            .help("Manage Backups")

            Button("New Database", systemImage: "plus.rectangle.on.folder") {
                workspace.requestNewDatabase()
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .disabled(workspace.selectedProfileID == nil)
            .help("Create Database")
        }
    }
}
