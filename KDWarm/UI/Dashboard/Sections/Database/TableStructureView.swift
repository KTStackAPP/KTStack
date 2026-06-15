import SwiftUI
import KDWarmKit

/// Read view of a table's columns + indexes, with DDL actions. Every DDL action composes SQL into
/// `vm.pendingDDL`, which this view shows verbatim in a confirm alert before anything runs — no blind
/// DDL. Create/Add-Column open `DDLActionSheet`; Drop actions stage SQL directly.
struct TableStructureView: View {
    @EnvironmentObject private var vm: DatabaseViewModel
    @State private var selectedColumn: String?
    @State private var ddlSheet: DDLActionSheet.Mode?

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            content
        }
        .task(id: vm.selectedTable) { await vm.loadStructure() }
        .sheet(item: $ddlSheet) { DDLActionSheet(mode: $0) }
        .alert("Run this SQL?", isPresented: ddlConfirmBinding, presenting: vm.pendingDDL) { _ in
            Button("Run", role: .destructive) { Task { await vm.confirmDDL() } }
            Button("Cancel", role: .cancel) { vm.cancelDDL() }
        } message: { Text($0) }
        .alert("DDL error", isPresented: ddlErrorBinding, presenting: vm.ddlError) { _ in
            Button("OK", role: .cancel) { vm.clearDDLError() }
        } message: { Text($0) }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if vm.selectedTable == nil {
            EmptyStateView(symbol: "tablecells.badge.ellipsis", title: "No table selected",
                           message: "Pick a table to inspect its columns and indexes.")
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: KDSpacing.space4) {
                    columnsSection
                    if !vm.currentIndexes.isEmpty { indexesSection }
                }
                .padding(KDSpacing.space3)
            }
        }
    }

    private var columnsSection: some View {
        VStack(alignment: .leading, spacing: KDSpacing.space2) {
            Text("Columns").font(KDFont.headline)
            ForEach(vm.currentColumns) { column in columnRow(column) }
        }
    }

    private func columnRow(_ column: ColumnInfo) -> some View {
        HStack(spacing: KDSpacing.space2) {
            Image(systemName: column.isPrimaryKey ? "key.fill" : "circle")
                .font(.system(size: 9))
                .foregroundStyle(column.isPrimaryKey ? Color.orange : Color.secondary.opacity(0.4))
            Text(column.name).font(KDFont.mono)
            Text(column.dataType).font(KDFont.footnote).foregroundStyle(.secondary)
            if !column.isNullable { Text("NOT NULL").font(KDFont.footnote).foregroundStyle(.tertiary) }
            Spacer()
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .background(selectedColumn == column.name ? Color.accentColor.opacity(0.15) : .clear)
        .onTapGesture { selectedColumn = column.name }
    }

    private var indexesSection: some View {
        VStack(alignment: .leading, spacing: KDSpacing.space2) {
            Text("Indexes").font(KDFont.headline)
            ForEach(vm.currentIndexes) { index in
                HStack(spacing: KDSpacing.space2) {
                    Image(systemName: index.isUnique ? "lock" : "number")
                        .font(.system(size: 10)).foregroundStyle(.secondary)
                    Text(index.name).font(KDFont.mono)
                    Text(index.columns.joined(separator: ", "))
                        .font(KDFont.footnote).foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.vertical, 2)
            }
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: KDSpacing.space2) {
            if let table = vm.selectedTable {
                Label(table.name, systemImage: "list.bullet.rectangle")
                    .font(KDFont.footnote).foregroundStyle(.secondary)
            }
            Spacer()
            if !vm.isReadOnlyConnection {
                Button { ddlSheet = .createTable } label: { Image(systemName: "plus.rectangle") }
                    .help("New table").disabled(vm.selectedDatabase == nil)
                Button { ddlSheet = .addColumn } label: { Image(systemName: "plus") }
                    .help("Add column").disabled(vm.selectedTable == nil)
                Button { vm.prepareDropColumn(selectedColumn ?? "") } label: { Image(systemName: "minus") }
                    .help("Drop selected column").disabled(selectedColumn == nil)
                Button { vm.prepareDropTable() } label: { Image(systemName: "trash") }
                    .help("Drop table").disabled(vm.selectedTable == nil)
            }
        }
        .padding(KDSpacing.space2)
    }

    // MARK: - Alert bindings

    private var ddlConfirmBinding: Binding<Bool> {
        Binding(get: { vm.pendingDDL != nil }, set: { if !$0 { vm.cancelDDL() } })
    }

    private var ddlErrorBinding: Binding<Bool> {
        Binding(get: { vm.ddlError != nil }, set: { if !$0 { vm.clearDDLError() } })
    }
}
