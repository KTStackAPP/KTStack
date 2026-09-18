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
            WorkspaceToolbarLeading(session: session)
            Spacer(minLength: 12)
            WorkspaceStatusPill(session: session)
            Spacer(minLength: 12)
            WorkspaceToolbarTrailing(session: session)
        }
        .padding(.horizontal, 12)
        .frame(height: 32)
    }
}

struct WorkspaceToolbarLeading: View {
    @ObservedObject var session: WorkspaceSession
    @ObservedObject var store: WorkspaceStore

    init(session: WorkspaceSession) {
        self.session = session
        self._store = ObservedObject(wrappedValue: session.store)
    }

    var body: some View {
        HStack(spacing: 2) {
            WorkspaceToolbarIconButton(
                title: "Toggle Sidebar (⌘0)",
                icon: "sidebar.left",
                isActive: store.sidebarVisible
            ) {
                store.sidebarVisible.toggle()
            }

            if session.shell.isConnected {
                let active = store.activeSession
                WorkspaceToolbarIconButton(
                    title: "Back",
                    icon: "chevron.left",
                    isDisabled: !(active?.vm.canGoBack ?? false)
                ) {
                    active?.vm.goBack()
                }

                WorkspaceToolbarIconButton(
                    title: "Forward",
                    icon: "chevron.right",
                    isDisabled: !(active?.vm.canGoForward ?? false)
                ) {
                    active?.vm.goForward()
                }

                WorkspaceToolbarIconButton(
                    title: "Reload (⌘R)",
                    icon: "arrow.clockwise"
                ) {
                    if store.activeSession != nil {
                        store.refreshActive()
                    } else if let db = session.shell.selectedDatabase {
                        Task { await session.shell.select(database: db) }
                    }
                }
            }
        }
    }
}

struct WorkspaceToolbarTrailing: View {
    @ObservedObject var session: WorkspaceSession
    @ObservedObject var store: WorkspaceStore

    init(session: WorkspaceSession) {
        self.session = session
        self._store = ObservedObject(wrappedValue: session.store)
    }

    var body: some View {
        HStack(spacing: 4) {
            if session.shell.isConnected {
                WorkspaceToolbarIconButton(
                    title: "Filter Tables (⌘F)",
                    icon: "magnifyingglass"
                ) {
                    store.focusFilter()
                }

                WorkspaceToolbarIconButton(
                    title: "New Query Tab (⌘T)",
                    icon: "plus"
                ) {
                    store.openQueryForActive()
                }

                toolbarDivider
            }

            WorkspaceWindowButtons(workspace: store)
            WorkspaceConnectionMenu(workspace: store)

            if session.shell.isConnected {
                toolbarDivider

                WorkspaceToolbarIconButton(
                    title: "Toggle Inspector (⌘⌥I)",
                    icon: "sidebar.right",
                    isActive: store.inspectorVisible
                ) {
                    store.inspectorVisible.toggle()
                }
            }
        }
    }

    private var toolbarDivider: some View {
        Rectangle()
            .fill(Color(nsColor: .separatorColor).opacity(0.45))
            .frame(width: 1, height: 14)
            .padding(.horizontal, 2)
    }
}

struct WorkspaceToolbarIconButton: View {
    let title: String
    let icon: String
    var isActive = false
    var isDisabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(isActive ? KTEditorTheme.accent : KTEditorTheme.label2)
                .frame(width: 28, height: 26)
                .contentShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.35 : 1.0)
        .help(title)
    }
}

struct WorkspaceConnectionMenu: View {
    @ObservedObject var workspace: WorkspaceStore

    var body: some View {
        Menu {
            Button("Disconnect") { workspace.requestDisconnect() }
                .disabled(workspace.selectedProfileID == nil)
            Button("Open Another Connection…") { workspace.requestOpenConnection() }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(KTEditorTheme.label2)
                .frame(width: 28, height: 26)
                .contentShape(RoundedRectangle(cornerRadius: 6))
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Connection Options")
    }
}

struct WorkspaceWindowButtons: View {
    @ObservedObject var workspace: WorkspaceStore

    var body: some View {
        HStack(spacing: 2) {
            WorkspaceToolbarIconButton(
                title: "Manage Backups",
                icon: "archivebox",
                isDisabled: workspace.selectedProfileID == nil
            ) {
                workspace.requestBackups()
            }

            WorkspaceToolbarIconButton(
                title: "Create Database",
                icon: "plus.rectangle.on.folder",
                isDisabled: workspace.selectedProfileID == nil
            ) {
                workspace.requestNewDatabase()
            }
        }
    }
}
