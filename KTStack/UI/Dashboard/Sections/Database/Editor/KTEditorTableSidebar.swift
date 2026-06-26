import SwiftUI
import KTStackKit

struct KTEditorTableSidebar: View {
    @EnvironmentObject private var vm: DatabaseViewModel
    @Binding var filter: String
    var onRefresh: () -> Void
    var onAddTable: () -> Void

    private var filteredTables: [TableInfo] {
        let query = filter.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return vm.tables }
        return vm.tables.filter { $0.name.lowercased().contains(query) }
    }

    var body: some View {
        VStack(spacing: 0) {
            databaseSwitcher
            header
            searchField
            tableList
        }
        .frame(width: 288)
        .background(KTEditorTheme.sidebar)
        .overlay(alignment: .trailing) { Rectangle().fill(KTEditorTheme.separator).frame(width: 0.5) }
    }

    @State private var switcherHovering = false

    private var databaseSwitcher: some View {
        Menu {
            if vm.databases.isEmpty {
                Text("No databases")
            } else {
                ForEach(vm.databases) { database in
                    Button {
                        guard database.name != vm.selectedDatabase else { return }
                        Task { await vm.select(database: database.name) }
                    } label: {
                        if database.name == vm.selectedDatabase {
                            Label(database.name, systemImage: "checkmark")
                        } else {
                            Text(database.name)
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 7) {
                Image(systemName: "cylinder.split.1x2").font(.system(size: 12.5)).foregroundStyle(KTEditorTheme.switcherIcon)
                Text(vm.selectedDatabase ?? "Select database")
                    .font(.jbMono(12.5, .semibold))
                    .foregroundStyle(vm.selectedDatabase == nil ? KTEditorTheme.label3 : KTEditorTheme.label)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Image(systemName: "chevron.down").font(.system(size: 10)).foregroundStyle(KTEditorTheme.label3)
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(switcherHovering ? KTEditorTheme.rowHover : Color.clear)
            .overlay(alignment: .bottom) { Rectangle().fill(KTEditorTheme.separator).frame(height: 1) }
            .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .disabled(vm.connection != .connected || vm.databases.isEmpty)
        .onHover { switcherHovering = $0 }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text("TABLES")
                .font(.jbMono(12.5, .bold))
                .foregroundStyle(KTEditorTheme.label2)
                .frame(maxWidth: .infinity, alignment: .leading)
            iconButton("arrow.clockwise", action: onRefresh)
            iconButton("plus", action: onAddTable)
        }
        .padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 8)
    }

    private func iconButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(KTEditorTheme.label2)
                .frame(width: 26, height: 26)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").font(.system(size: 12)).foregroundStyle(KTEditorTheme.label3)
            TextField("Filter tables…", text: $filter)
                .textFieldStyle(.plain)
                .font(.jbMono(13))
                .foregroundStyle(KTEditorTheme.label)
        }
        .padding(.horizontal, 11).padding(.vertical, 7)
        .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(KTEditorTheme.fieldBg))
        .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).stroke(KTEditorTheme.separator, lineWidth: 0.5))
        .padding(.horizontal, 12).padding(.bottom, 8)
    }

    private var tableList: some View {
        ScrollView {
            LazyVStack(spacing: 1) {
                ForEach(filteredTables) { table in
                    tableRow(table)
                }
            }
            .padding(.horizontal, 8).padding(.bottom, 10)
        }
    }

    private func tableRow(_ table: TableInfo) -> some View {
        let active = vm.selectedTable?.name == table.name
        return Button { Task { await vm.select(table: table) } } label: {
            HStack(spacing: 9) {
                Image(systemName: table.isView ? "eye" : "tablecells")
                    .font(.system(size: 13))
                    .foregroundStyle(active ? KTEditorTheme.onAccent : KTEditorTheme.label3)
                Text(table.name)
                    .font(.jbMono(13, .regular))
                    .foregroundStyle(active ? KTEditorTheme.onAccent : KTEditorTheme.label)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10).padding(.vertical, 7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(active ? KTEditorTheme.accent : Color.clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
