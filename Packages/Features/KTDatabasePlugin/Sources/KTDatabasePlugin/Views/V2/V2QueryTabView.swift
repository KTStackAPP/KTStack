import KTPluginKit
import SwiftUI

struct V2QueryTabView: View {
    @ObservedObject var vm: DatabaseV2ViewModel

    var body: some View {
        VStack(spacing: 0) {
            queryTabsBar
            toolbar
            sqlEditor
            Divider().overlay(KTEditorTheme.separator)
            V2QueryResultArea(vm: vm)
        }
    }

    private var queryTabsBar: some View {
        HStack(spacing: 0) {
            ForEach(vm.queryTabs) { tab in
                tabButton(tab)
            }
            addButton
            Spacer(minLength: 0)
        }
        .frame(height: 34)
        .background(KTEditorTheme.content2)
        .overlay(alignment: .bottom) {
            Divider().overlay(KTEditorTheme.separator)
        }
    }

    private func tabButton(_ tab: V2QueryTab) -> some View {
        let active = tab.id == vm.activeQueryTabID
        return HStack(spacing: 8) {
            if tab.isRunning {
                ProgressView().controlSize(.mini).scaleEffect(0.65).frame(width: 12, height: 12)
            }
            Text(tab.title)
                .font(.system(size: 12))
                .foregroundStyle(active ? KTEditorTheme.label : KTEditorTheme.label2)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
            if vm.queryTabs.count > 1 {
                Button {
                    vm.closeQueryTab(id: tab.id)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .regular))
                        .foregroundStyle(KTEditorTheme.label3)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .frame(maxHeight: .infinity)
        .background(active ? KTEditorTheme.content : Color.clear)
        .overlay(alignment: .trailing) {
            Rectangle().fill(KTEditorTheme.separator).frame(width: 1)
        }
        .contentShape(Rectangle())
        .onTapGesture { vm.selectQueryTab(id: tab.id) }
    }

    private var addButton: some View {
        Button { vm.addQueryTab() } label: {
            Image(systemName: "plus")
                .font(.system(size: 13, weight: .regular))
                .foregroundStyle(KTEditorTheme.label2)
                .padding(.horizontal, 12)
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var toolbar: some View {
        HStack(spacing: 10) {
            if vm.isRunning {
                if vm.capabilities.canCancelQueries {
                    V2Button(title: "Cancel", systemImage: "stop.fill", kind: .danger) {
                        Task { await vm.cancelQuery() }
                    }
                }
            } else {
                V2Button(title: "Run Query", systemImage: "play.fill", kind: .primary) {
                    Task { await vm.runQuery() }
                }
                .keyboardShortcut(.return, modifiers: .command)
                V2Button(title: "Format", systemImage: "text.alignleft", kind: .standard) {
                    vm.requestFormat()
                }
                .keyboardShortcut("l", modifiers: [.command, .shift])
                V2Button(title: "Explain", systemImage: "list.bullet.indent", kind: .standard) {
                    Task { await vm.explainActiveQuery() }
                }
                databaseMenu
            }
            Spacer()
            libraryActions
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var databaseMenu: some View {
        Menu {
            Button { vm.setQueryDatabase(nil) } label: {
                let label = "Follow sidebar (\(vm.selectedDatabase ?? "none"))"
                if vm.activeQueryTab?.database == nil { Label(label, systemImage: "checkmark") } else { Text(label) }
            }
            if !vm.databases.isEmpty { Divider() }
            ForEach(vm.databases, id: \.name) { db in
                Button { vm.setQueryDatabase(db.name) } label: {
                    if vm.activeQueryTab?.database == db.name { Label(db.name, systemImage: "checkmark") } else { Text(db.name) }
                }
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "cylinder.split.1x2").font(.system(size: 11))
                Text(vm.activeQueryTab?.database ?? vm.selectedDatabase ?? "Database")
                    .font(.system(size: 12)).lineLimit(1)
            }
            .foregroundStyle(KTEditorTheme.label2)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private var libraryActions: some View {
        HStack(spacing: 8) {
            V2Button(title: "History", systemImage: "clock.arrow.circlepath", kind: .standard) {
                vm.showHistory()
            }
            V2Button(title: "Favorites", systemImage: "star", kind: .standard) {
                vm.showFavorites()
            }
            V2Button(title: "Open", systemImage: "folder", kind: .standard) {
                if let file = SQLDocumentPanel.open() { vm.loadSQLFile(name: file.name, text: file.text) }
            }
            V2Button(title: "Save", systemImage: "square.and.arrow.down", kind: .standard) {
                SQLDocumentPanel.save(text: vm.queryText)
            }
        }
    }

    private var activeTextBinding: Binding<String> {
        Binding(
            get: { vm.queryText },
            set: { vm.queryText = $0 }
        )
    }

    private var sqlEditor: some View {
        SQLCodeEditor(
            text: activeTextBinding,
            catalog: vm.schemaCatalog,
            keywords: SQLKeywords.forKind(vm.connectionKind ?? .mysql),
            formatTrigger: vm.formatTrigger
        )
        .id(vm.activeQueryTabID)
        .frame(height: 132)
        .padding(6)
        .background(KTEditorTheme.content)
        .overlay(
            RoundedRectangle(cornerRadius: 11)
                .stroke(KTEditorTheme.separator, lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
        .task(id: vm.selectedDatabase) { await vm.loadDiagram() }
    }
}
