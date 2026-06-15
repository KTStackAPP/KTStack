import SwiftUI
import KDWarmKit


struct SchemaTreeView: View {
    @EnvironmentObject private var vm: DatabaseViewModel
    
    @State private var expanded: Set<String> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Schema")
                .font(KDFont.footnote).foregroundStyle(.secondary)
                .padding(.horizontal, KDSpacing.space3)
                .padding(.vertical, KDSpacing.space2)
            Divider()
            content
        }
        .frame(minWidth: 180, idealWidth: 220)
    }

    @ViewBuilder
    private var content: some View {
        if vm.connection == .connected {
            List {
                ForEach(vm.databases) { db in databaseRow(db) }
            }
            .listStyle(.sidebar)
        } else {
            VStack {
                Spacer()
                Text("Pick a connection to browse its schema.")
                    .font(KDFont.footnote).foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center).padding(KDSpacing.space3)
                Spacer()
            }
            .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private func databaseRow(_ db: DatabaseInfo) -> some View {
        DisclosureGroup(isExpanded: expandedBinding(db.name)) {
            if vm.selectedDatabase == db.name {
                ForEach(vm.tables) { table in tableRow(table) }
            }
        } label: {
            Label(db.name, systemImage: "cylinder").font(KDFont.body)
        }
    }

    @ViewBuilder
    private func tableRow(_ table: TableInfo) -> some View {
        let isSelected = vm.selectedTable?.id == table.id
        HStack(spacing: KDSpacing.space2) {
            Image(systemName: table.isView ? "eye" : "tablecells")
                .foregroundStyle(isSelected ? Color.accentColor : .secondary)
            Text(table.name).font(KDFont.body)
            if table.isView {
                Text("view").font(KDFont.footnote).foregroundStyle(.tertiary)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 1)
        .contentShape(Rectangle())
        .onTapGesture { Task { await vm.select(table: table) } }
    }

    
    private func expandedBinding(_ name: String) -> Binding<Bool> {
        Binding(
            get: { expanded.contains(name) },
            set: { isOpen in
                if isOpen {
                    expanded.insert(name)
                    if vm.selectedDatabase != name { Task { await vm.select(database: name) } }
                } else {
                    expanded.remove(name)
                }
            })
    }
}
