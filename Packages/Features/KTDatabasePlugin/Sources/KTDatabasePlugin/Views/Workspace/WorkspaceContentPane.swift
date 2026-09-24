import AppKit
import KTPluginKit
import SwiftUI

struct WorkspaceContentPane: View {
    @ObservedObject var model: WorkspaceRootModel
    @ObservedObject var vm: DatabaseV2ViewModel
    @ObservedObject var workspace: WorkspaceStore
    @ObservedObject var sectionState: DatabaseSectionState

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(KTEditorTheme.window)
            .background(shortcuts)
            .overlay { modalLayer }
            .sheet(item: $model.editSheet) { profile in AddConnectionSheet(editing: profile) }
            .sheet(isPresented: $model.showBackups) {
                WorkspaceBackupsSheet(admin: model.admin, session: model.backupSession)
            }
            .onChange(of: workspace.backupsRequest) { _ in model.presentBackups() }
            .onChange(of: workspace.newDatabaseRequest) { _ in model.presentNewDatabase() }
            .onChange(of: workspace.disconnectRequest) { _ in model.requestDisconnect() }
            .onChange(of: workspace.openConnectionRequest) { _ in openConnectionInNewTab() }
            .alert("Ngắt kết nối?", isPresented: $model.confirmDisconnect) {
                Button("Huỷ", role: .cancel) {}
                Button("Ngắt & bỏ thay đổi", role: .destructive) { model.performDisconnect() }
            } message: {
                Text("Còn \(workspace.pendingChangeTotal) thay đổi chưa commit sẽ bị bỏ khi ngắt kết nối.")
            }
            .alert(item: $model.pendingCloseTab) { pending in
                Alert(
                    title: Text("Discard pending changes?"),
                    message: Text("\(pending.count) pending change\(pending.count == 1 ? "" : "s") in this tab will be discarded if you close it."),
                    primaryButton: .destructive(Text("Discard & Close")) {
                        workspace.closeTab(pending.id, force: true)
                    },
                    secondaryButton: .cancel()
                )
            }
            .onChange(of: workspace.activationToken) { _ in
                if let id = workspace.activationProfileID, !model.isConnected { model.activate(profileID: id) }
            }
            .onAppear {
                workspace.startPolling()
                if let id = model.initialProfileID, !model.isConnected { model.activate(profileID: id) }
            }
            .onDisappear { workspace.stopPolling() }
            .ktFeedbackHost(model.feedback)
            .environmentObject(model.admin)
            .environmentObject(model.documentVM)
            .environmentObject(model.connectionStore)
    }

    @ViewBuilder
    private var content: some View {
        if model.isConnected {
            VStack(spacing: 0) {
                WorkspaceTabBar(
                    workspace: workspace,
                    onNewQuery: { model.openQueryTab() },
                    onClose: { model.requestCloseTab($0) }
                )
                activePane
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        } else {
            ConnectionsPageView(
                profiles: workspace.profiles,
                statusFor: { workspace.status(for: $0) },
                engineInstalled: model.engineInstalled,
                engineRunning: { model.engines.isRunning($0) },
                recents: workspace.recentStore.recent(),
                lastDatabaseFor: { model.lastUsed.lastDatabase(for: $0) },
                recentDatabasesFor: { workspace.recentStore.recentDatabases(for: $0) },
                selectedID: $workspace.selectedProfileID,
                onOpen: { model.activate(profileID: $0.id) },
                onOpenDatabase: { profile, db in model.activate(profileID: profile.id, database: db) },
                onOpenRecent: model.openRecent,
                onNewConnection: { sectionState.connectPresented = true },
                onInstallEngine: model.openRuntimes,
                contextActions: model.profileContextActions
            )
        }
    }

    @ViewBuilder
    private var activePane: some View {
        if let session = workspace.activeSession {
            if session.kind.isQuery {
                WorkspaceQueryPane(vm: session.vm).id(session.id)
            } else {
                WorkspaceTablePane(vm: session.vm, workspace: workspace, session: session)
                    .id(session.id)
            }
        } else {
            noTabPlaceholder
        }
    }

    private var noTabPlaceholder: some View {
        VStack(spacing: 8) {
            Image(systemName: "tablecells")
                .font(.system(size: 28))
                .foregroundStyle(KTEditorTheme.faint)
            Text("Select a table in the sidebar to open")
                .font(.system(size: 13))
                .foregroundStyle(KTEditorTheme.label3)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(KTEditorTheme.content)
    }

    private func openConnectionInNewTab() {
        NSApp.sendAction(#selector(NSWindow.newWindowForTab(_:)), to: nil, from: nil)
    }

    private var shortcuts: some View {
        ZStack {
            Button("") { model.openQueryTab() }.keyboardShortcut("t", modifiers: .command)
            Button("") { openConnectionInNewTab() }.keyboardShortcut("t", modifiers: [.command, .shift])
            Button("") { model.requestCloseActiveTab() }.keyboardShortcut("w", modifiers: .command)
            Button("") { workspace.focusFilter() }.keyboardShortcut("f", modifiers: .command)
            Button("") { workspace.sidebarVisible.toggle() }.keyboardShortcut("0", modifiers: .command)
            Button("") { workspace.inspectorVisible.toggle() }.keyboardShortcut("i", modifiers: [.command, .option])
        }
        .opacity(0)
        .frame(width: 0, height: 0)
        .accessibilityHidden(true)
    }

    private var modalLayer: some View {
        ZStack {
            if sectionState.connectPresented {
                KTConnectModal(
                    onClose: { sectionState.connectPresented = false },
                    onConnected: { _ in sectionState.connectPresented = false }
                )
                .transition(.opacity)
            }
            if sectionState.newDatabasePresented {
                KTNewDatabaseModal(
                    onClose: { sectionState.newDatabasePresented = false },
                    onCreated: { newName in
                        sectionState.newDatabasePresented = false
                        Task {
                            await vm.reloadDatabases()
                            model.selectDatabase(newName)
                        }
                    }
                )
                .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.15), value: sectionState.connectPresented)
        .animation(.easeOut(duration: 0.15), value: sectionState.newDatabasePresented)
    }
}
