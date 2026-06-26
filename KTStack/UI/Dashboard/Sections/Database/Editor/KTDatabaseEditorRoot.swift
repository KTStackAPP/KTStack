import SwiftUI
import KTStackKit

struct KTDatabaseEditorRoot: View {
    @EnvironmentObject private var vm: DatabaseViewModel
    let onClose: () -> Void

    enum EditorTab: Hashable { case data, structure, query, er }

    @State private var tab: EditorTab = .data
    @State private var tableFilter = ""
    @State private var selectedRow: Int?
    @State private var rowEditor: RowEditorMode?
    @State private var pendingDelete: Int?
    @State private var ddlSheet: DDLActionSheet.Mode?

    private var schemaName: String {
        vm.selectedDatabase ?? vm.selectedProfile?.name ?? "database"
    }

    var body: some View {
        VStack(spacing: 0) {
            titlebar
            objectTabs
            if vm.connection == .connected {
                HStack(spacing: 0) {
                    KTEditorTableSidebar(filter: $tableFilter,
                                         onRefresh: { Task { await reloadCurrentDatabase() } },
                                         onAddTable: { ddlSheet = .createTable })
                    tabContent
                }
            } else {
                disconnectedState
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(KTEditorTheme.window)
        .background(escCatcher)
        .onChange(of: vm.selectedTable) { _ in selectedRow = nil; pendingDelete = nil }
        .sheet(item: $rowEditor) { RowEditorView(mode: $0) }
        .sheet(item: $ddlSheet) { DDLActionSheet(mode: $0) }
        .alert("Delete this row?", isPresented: deleteBinding, presenting: pendingDelete) { row in
            Button("Delete", role: .destructive) { Task { await vm.deleteRow(at: row); selectedRow = nil } }
            Button("Cancel", role: .cancel) {}
        } message: { _ in Text("This permanently removes the row from the table.") }
        .alert("Edit failed", isPresented: editErrorBinding, presenting: vm.editError) { _ in
            Button("OK", role: .cancel) { vm.clearEditError() }
        } message: { Text($0) }
        .alert("Run this SQL?", isPresented: ddlConfirmBinding, presenting: vm.pendingDDL) { _ in
            Button("Run", role: .destructive) { Task { await vm.confirmDDL() } }
            Button("Cancel", role: .cancel) { vm.cancelDDL() }
        } message: { Text($0) }
        .alert("DDL error", isPresented: ddlErrorBinding, presenting: vm.ddlError) { _ in
            Button("OK", role: .cancel) { vm.clearDDLError() }
        } message: { Text($0) }
    }

    private var titlebar: some View {
        HStack(spacing: 11) {
            KTIconTile(tint: KTIconTint.db, size: 26, radius: 7) {
                Image(systemName: "cylinder.split.1x2").font(.system(size: 13, weight: .medium))
            }
            HStack(spacing: 6) {
                Text("SQL Editor")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(KTEditorTheme.label)
                Text(schemaName)
                    .font(.jbMono(13, .medium))
                    .foregroundStyle(KTEditorTheme.label2)
            }
            Spacer()
            connectionPill
        }
        .frame(height: 44)
        .padding(.leading, 78).padding(.trailing, 14)
        .background(LinearGradient(colors: [KTEditorTheme.titlebarTop, KTEditorTheme.titlebarBottom],
                                   startPoint: .top, endPoint: .bottom))
    }

    private var objectTabs: some View {
        KTEditorObjectTabs(items: [.init(value: EditorTab.data, label: "Data", systemImage: "tablecells"),
                                   .init(value: .structure, label: "Structure", systemImage: "list.bullet.rectangle"),
                                   .init(value: .query, label: "Query", systemImage: "chevron.left.forwardslash.chevron.right"),
                                   .init(value: .er, label: "ER", systemImage: "point.3.connected.trianglepath.dotted")],
                           selection: $tab)
    }

    @ViewBuilder
    private var connectionPill: some View {
        switch vm.connection {
        case .connected:
            pill(color: KTEditorTheme.Status.running, text: "Connected")
        case .connecting:
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("Connecting…").font(.jbMono(11)).foregroundStyle(KTEditorTheme.label2)
            }
            .padding(.horizontal, 8).padding(.vertical, 2)
            .background(Capsule().fill(KTEditorTheme.pillBg))
        default:
            pill(color: KTEditorTheme.Status.error, text: "Disconnected")
        }
    }

    private func pill(color: Color, text: String) -> some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 7, height: 7)
                .shadow(color: color.opacity(0.6), radius: 2)
            Text(text).font(.jbMono(11)).foregroundStyle(KTEditorTheme.label2)
        }
        .padding(.horizontal, 8).padding(.vertical, 2)
        .background(Capsule().fill(KTEditorTheme.pillBg))
    }

    private var disconnectedState: some View {
        VStack(spacing: 8) {
            Image(systemName: "cylinder.split.1x2")
                .font(.system(size: 42, weight: .light))
                .foregroundStyle(KTEditorTheme.label3)
            Text("Not connected")
                .font(.jbMono(15, .regular))
                .foregroundStyle(KTEditorTheme.label2)
            Text("Connect to a database from the dashboard to browse it here.")
                .font(.jbMono(12))
                .foregroundStyle(KTEditorTheme.label3)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(KTEditorTheme.content)
    }

    private var tabContent: some View {
        ZStack {
            KTEditorDataTab(selectedRow: $selectedRow, editor: $rowEditor,
                            pendingDelete: $pendingDelete, isActive: tab == .data)
                .opacity(tab == .data ? 1 : 0).allowsHitTesting(tab == .data)
            KTEditorStructureTab(isActive: tab == .structure)
                .opacity(tab == .structure ? 1 : 0).allowsHitTesting(tab == .structure)
            KTEditorQueryTab(isActive: tab == .query)
                .opacity(tab == .query ? 1 : 0).allowsHitTesting(tab == .query)
            KTEditorERTab(isActive: tab == .er)
                .opacity(tab == .er ? 1 : 0).allowsHitTesting(tab == .er)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func reloadCurrentDatabase() async {
        guard let database = vm.selectedDatabase else { return }
        await vm.select(database: database)
    }

    private var escCatcher: some View {
        Button(action: onClose) { Color.clear }
            .keyboardShortcut(.cancelAction).opacity(0).frame(width: 0, height: 0).accessibilityHidden(true)
    }

    private var deleteBinding: Binding<Bool> {
        Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } })
    }
    private var editErrorBinding: Binding<Bool> {
        Binding(get: { vm.editError != nil }, set: { if !$0 { vm.clearEditError() } })
    }
    private var ddlConfirmBinding: Binding<Bool> {
        Binding(get: { vm.pendingDDL != nil }, set: { if !$0 { vm.cancelDDL() } })
    }
    private var ddlErrorBinding: Binding<Bool> {
        Binding(get: { vm.ddlError != nil }, set: { if !$0 { vm.clearDDLError() } })
    }
}

struct EditorTabTaskKey<Value: Equatable>: Equatable {
    let value: Value
    let isActive: Bool
}
