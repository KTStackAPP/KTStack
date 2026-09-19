import KTPluginKit
import SwiftUI

struct WorkspaceFilterBar: View {
    @ObservedObject var vm: DatabaseV2ViewModel
    @ObservedObject var workspace: WorkspaceStore

    @State private var conditions: [EditableCondition] = []
    @State private var showSQL = false
    @State private var sortColumn: String?
    @State private var sortAscending = true

    private var columnNames: [String] { vm.columns.map(\.name) }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "line.3.horizontal.decrease")
                    .font(.system(size: 11))
                    .foregroundStyle(conditions.isEmpty ? KTEditorTheme.label3 : KTEditorTheme.accent)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach($conditions) { $condition in
                            conditionChip($condition)
                        }
                        addButton
                    }
                }

                Spacer(minLength: 8)
                orderByMenu
                presetMenu
                V2IconButton(
                    systemImage: "curlybraces",
                    tint: showSQL ? KTEditorTheme.accent : KTEditorTheme.label2
                ) { showSQL.toggle() }
                if !conditions.isEmpty || vm.browseSort != nil {
                    V2Button(title: "Bỏ lọc", kind: .danger) { clear() }
                }
                V2Button(title: "Áp dụng", kind: .primary) { apply() }
                    .keyboardShortcut(.return, modifiers: [])
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 7)

            if showSQL {
                sqlPreview
            }
        }
        .background(KTEditorTheme.content2)
        .overlay(alignment: .bottom) { Divider().overlay(KTEditorTheme.separator) }
        .onAppear(perform: syncFromVM)
        .onChange(of: vm.selectedTable?.name) { _ in syncFromVM() }
        .onChange(of: workspace.filterFocusToken) { _ in
            if conditions.isEmpty, let first = columnNames.first {
                conditions.append(EditableCondition(column: first, op: .equals, value: ""))
            }
        }
    }

    private func conditionChip(_ condition: Binding<EditableCondition>) -> some View {
        HStack(spacing: 4) {
            Menu(condition.wrappedValue.column.isEmpty ? "cột" : condition.wrappedValue.column) {
                ForEach(columnNames, id: \.self) { name in
                    Button(name) { condition.wrappedValue.column = name }
                }
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .font(.system(size: 11, design: .monospaced))

            Menu(condition.wrappedValue.op.symbol) {
                ForEach(FilterOperator.allCases, id: \.self) { op in
                    Button(op.symbol) { condition.wrappedValue.op = op }
                }
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .font(.system(size: 11, weight: .semibold, design: .monospaced))

            if condition.wrappedValue.op.bindsValue {
                TextField("giá trị", text: condition.value)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11, design: .monospaced))
                    .frame(width: 90)
            }
            Button {
                conditions.removeAll { $0.id == condition.wrappedValue.id }
            } label: {
                Image(systemName: "xmark").font(.system(size: 8, weight: .semibold)).foregroundStyle(KTEditorTheme.label3)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(nsColor: .separatorColor).opacity(0.6), lineWidth: 0.5))
    }

    private var addButton: some View {
        Button {
            conditions.append(EditableCondition(column: columnNames.first ?? "", op: .equals, value: ""))
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "plus").font(.system(size: 9))
                Text("Điều kiện").font(.system(size: 11, weight: .medium))
            }
            .foregroundStyle(KTEditorTheme.label2)
        }
        .buttonStyle(.plain)
        .disabled(columnNames.isEmpty)
    }

    private var orderByMenu: some View {
        Menu {
            Button("Không sắp xếp") { sortColumn = nil }
            Divider()
            ForEach(columnNames, id: \.self) { name in
                Button("\(name) ↑") { sortColumn = name; sortAscending = true }
                Button("\(name) ↓") { sortColumn = name; sortAscending = false }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "arrow.up.arrow.down").font(.system(size: 10))
                Text(sortLabel).font(.system(size: 11, design: .monospaced))
            }
            .foregroundStyle(sortColumn == nil ? KTEditorTheme.label2 : KTEditorTheme.accent)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private var sortLabel: String {
        guard let sortColumn else { return "ORDER BY" }
        return "\(sortColumn) \(sortAscending ? "↑" : "↓")"
    }

    private var presetMenu: some View {
        Menu {
            if vm.savedPresets.isEmpty { Text("Chưa có preset") }
            ForEach(vm.savedPresets, id: \.name) { preset in
                Button("\(preset.name) (\(preset.conditions.count))") {
                    conditions = preset.conditions.map(EditableCondition.init)
                }
            }
            if !builtConditions.isEmpty {
                Divider()
                Button("Lưu điều kiện hiện tại…") { savePreset() }
            }
        } label: {
            Image(systemName: "bookmark").font(.system(size: 11)).foregroundStyle(KTEditorTheme.label2)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }

    private var sqlPreview: some View {
        HStack(spacing: 6) {
            Text("WHERE")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(KTEditorTheme.label3)
            Text(FilterDraft.previewWhere(conditions, kind: vm.connectionKind ?? .mysql) ?? "(toàn bảng)")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(KTEditorTheme.label2)
                .textSelection(.enabled)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 5)
        .background(KTEditorTheme.window)
        .overlay(alignment: .top) { Divider().overlay(KTEditorTheme.separator) }
    }

    private var builtConditions: [FilterCondition] { FilterDraft.conditions(conditions) }

    private func apply() {
        vm.applyFilters(builtConditions)
        vm.setBrowseSort(sortColumn.map { SortSpec(column: $0, ascending: sortAscending) })
    }

    private func clear() {
        conditions = []
        sortColumn = nil
        vm.applyFilters([])
        vm.setBrowseSort(nil)
    }

    private func savePreset() {
        vm.savePreset(name: "Preset \(vm.savedPresets.count + 1)", conditions: builtConditions)
    }

    private func syncFromVM() {
        conditions = vm.activeFilters.map(EditableCondition.init)
        sortColumn = vm.browseSort?.column
        sortAscending = vm.browseSort?.ascending ?? true
    }
}
