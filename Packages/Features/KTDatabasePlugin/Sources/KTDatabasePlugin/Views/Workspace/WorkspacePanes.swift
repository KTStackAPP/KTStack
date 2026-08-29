import AppKit
import KTPluginKit
import SwiftUI

// MARK: Sidebar pane

/// Pane trái: ô lọc + cây object (Tables/Views/Queries) + footer đếm. Không còn nhóm Connections.
struct WorkspaceSidebarPane: View {
    @ObservedObject var model: WorkspaceRootModel
    @ObservedObject var vm: DatabaseV2ViewModel
    @ObservedObject var workspace: WorkspaceStore

    var body: some View {
        VStack(spacing: 0) {
            searchField
            Divider().overlay(KTEditorTheme.separator)
            WorkspaceSidebar(
                nodes: model.nodes,
                selectedNodeID: model.selectedNodeID,
                onSelectObject: { model.selectObject($0, forceNewTab: false) },
                onOpenInNewTab: { model.selectObject($0, forceNewTab: true) },
                contextActions: { _ in [] }
            )
            Divider().overlay(KTEditorTheme.separator)
            footer
        }
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundStyle(KTEditorTheme.label3)
            TextField("Lọc bảng…", text: $model.filter)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
            if !model.filter.isEmpty {
                Button { model.filter = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(KTEditorTheme.label3)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(KTEditorTheme.fieldBg, in: RoundedRectangle(cornerRadius: 7))
        .padding(10)
    }

    private var footer: some View {
        let tables = model.currentObjects.filter { !$0.isView }.count
        let views = model.currentObjects.filter(\.isView).count
        return HStack(spacing: 6) {
            Text("\(tables) bảng · \(views) view")
                .font(.system(size: 11))
                .foregroundStyle(KTEditorTheme.label2)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

// MARK: Content pane

/// Pane giữa: tab bar + tab object khi đã nối, trang kết nối khi chưa nối; kèm modal/sheet/alert + phím tắt.
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
                WorkspaceBackupsSheet(vm: model.databaseVM, session: model.backupSession, feedback: model.feedback)
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
                selectedID: $workspace.selectedProfileID,
                onOpen: { model.activate(profileID: $0.id) },
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
                WorkspaceTablePane(
                    vm: session.vm,
                    workspace: workspace,
                    selectedRow: Binding(
                        get: { session.selectedRowIndex },
                        set: { session.selectedRowIndex = $0 }
                    )
                )
                .id(session.id)
            }
        } else {
            noTabPlaceholder
        }
    }

    private var noTabPlaceholder: some View {
        VStack(spacing: 8) {
            Image(systemName: "tablecells").font(.system(size: 28)).foregroundStyle(KTEditorTheme.faint)
            Text("Chọn một bảng ở sidebar để mở tab")
                .font(.system(size: 13)).foregroundStyle(KTEditorTheme.label3)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(KTEditorTheme.content)
    }

    /// "Mở kết nối khác…": nhờ key window (TabbingWindow) mở tab mới với trang kết nối.
    private func openConnectionInNewTab() {
        NSApp.sendAction(#selector(NSWindow.newWindowForTab(_:)), to: nil, from: nil)
    }

    private var shortcuts: some View {
        ZStack {
            Button("") { model.openQueryTab() }.keyboardShortcut("t", modifiers: .command)
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
                    onCreated: { _ in sectionState.newDatabasePresented = false }
                )
                .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.15), value: sectionState.connectPresented)
        .animation(.easeOut(duration: 0.15), value: sectionState.newDatabasePresented)
    }
}

// MARK: Inspector pane

/// Pane phải: chi tiết dòng đang chọn của tab bảng đang active; rỗng nếu là tab query hoặc không có tab.
struct WorkspaceInspectorPane: View {
    @ObservedObject var model: WorkspaceRootModel
    @ObservedObject var workspace: WorkspaceStore

    var body: some View {
        Group {
            if let session = workspace.activeSession, !session.kind.isQuery {
                WorkspaceInspector(vm: session.vm, selectedRow: model.activeSelectedRow)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "sidebar.right").font(.system(size: 22)).foregroundStyle(KTEditorTheme.faint)
                    Text("Chọn một dòng để xem chi tiết")
                        .font(.system(size: 12)).foregroundStyle(KTEditorTheme.label3)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(KTEditorTheme.content2)
            }
        }
    }
}
