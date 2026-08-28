import KTPluginKit
import SwiftUI

struct V2FilterSheet: View {
    @ObservedObject var vm: DatabaseV2ViewModel
    let onClose: () -> Void

    @State private var conditions: [EditableCondition]
    @State private var presetName: String = ""

    init(vm: DatabaseV2ViewModel, onClose: @escaping () -> Void) {
        self.vm = vm
        self.onClose = onClose
        _conditions = State(initialValue: vm.activeFilters.map(EditableCondition.init))
    }

    private var columnNames: [String] { vm.columns.map(\.name) }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    conditionList
                    Divider().overlay(KTEditorTheme.separator)
                    presetSection
                }
                .padding(16)
            }
            footer
        }
        .frame(width: 620, height: 460)
        .background(KTEditorTheme.window)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "line.3.horizontal.decrease")
                .font(.system(size: 12))
                .foregroundStyle(KTEditorTheme.accent)
            Text("Filter \(vm.selectedTable?.name ?? "")")
                .font(.jbMono(13))
                .foregroundStyle(KTEditorTheme.label)
            Spacer()
            V2Button(title: "Close") { onClose() }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .overlay(alignment: .bottom) { Divider().overlay(KTEditorTheme.separator) }
    }

    private var conditionList: some View {
        VStack(alignment: .leading, spacing: 8) {
            if conditions.isEmpty {
                Text("No conditions. Add one to filter rows.")
                    .font(.jbMono(12))
                    .foregroundStyle(KTEditorTheme.label3)
            }
            ForEach($conditions) { $condition in
                conditionRow($condition)
            }
            V2Button(title: "Add condition", systemImage: "plus") {
                conditions.append(EditableCondition(column: columnNames.first ?? "", op: .equals, value: ""))
            }
            .disabled(columnNames.isEmpty)
        }
    }

    private func conditionRow(_ condition: Binding<EditableCondition>) -> some View {
        HStack(spacing: 8) {
            Menu(condition.wrappedValue.column.isEmpty ? "column" : condition.wrappedValue.column) {
                ForEach(columnNames, id: \.self) { name in
                    Button(name) { condition.wrappedValue.column = name }
                }
            }
            .font(.jbMono(12))
            .frame(width: 150, alignment: .leading)

            Menu(condition.wrappedValue.op.symbol) {
                ForEach(FilterOperator.allCases, id: \.self) { op in
                    Button(op.symbol) { condition.wrappedValue.op = op }
                }
            }
            .font(.jbMono(12))
            .frame(width: 90, alignment: .leading)

            TextField("value", text: condition.value)
                .textFieldStyle(.roundedBorder)
                .font(.jbMono(12))
                .disabled(!condition.wrappedValue.op.bindsValue)

            V2IconButton(systemImage: "minus.circle", tint: KTEditorTheme.Status.error) {
                conditions.removeAll { $0.id == condition.wrappedValue.id }
            }
        }
    }

    private var presetSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Saved presets")
                .font(.jbMono(12).weight(.semibold))
                .foregroundStyle(KTEditorTheme.label2)
            if vm.savedPresets.isEmpty {
                Text("None saved for this table.")
                    .font(.jbMono(11))
                    .foregroundStyle(KTEditorTheme.label3)
            }
            ForEach(vm.savedPresets, id: \.name) { preset in
                HStack(spacing: 8) {
                    Text(preset.name)
                        .font(.jbMono(12))
                        .foregroundStyle(KTEditorTheme.label)
                    Text("\(preset.conditions.count) condition\(preset.conditions.count == 1 ? "" : "s")")
                        .font(.jbMono(11))
                        .foregroundStyle(KTEditorTheme.label3)
                    Spacer()
                    V2Button(title: "Load") { conditions = preset.conditions.map(EditableCondition.init) }
                    V2IconButton(systemImage: "trash", tint: KTEditorTheme.Status.error) {
                        vm.deletePreset(preset)
                    }
                }
            }
            HStack(spacing: 8) {
                TextField("preset name", text: $presetName)
                    .textFieldStyle(.roundedBorder)
                    .font(.jbMono(12))
                V2Button(title: "Save preset") {
                    vm.savePreset(name: presetName, conditions: builtConditions)
                    presetName = ""
                }
                .disabled(presetName.trimmingCharacters(in: .whitespaces).isEmpty || builtConditions.isEmpty)
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 8) {
            V2Button(title: "Clear", kind: .danger) {
                conditions = []
                vm.applyFilters([])
                onClose()
            }
            Spacer()
            V2Button(title: "Apply", kind: .primary) {
                vm.applyFilters(builtConditions)
                onClose()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .overlay(alignment: .top) { Divider().overlay(KTEditorTheme.separator) }
    }

    private var builtConditions: [FilterCondition] {
        conditions.compactMap { $0.toCondition() }
    }
}

// Bản dựng UI cho một điều kiện lọc: value là chuỗi, chuyển sang Cell khi Apply.
struct EditableCondition: Identifiable {
    let id = UUID()
    var column: String
    var op: FilterOperator
    var value: String

    init(column: String, op: FilterOperator, value: String) {
        self.column = column
        self.op = op
        self.value = value
    }

    init(_ condition: FilterCondition) {
        self.column = condition.column
        self.op = condition.op
        self.value = condition.value.displayText ?? ""
    }

    func toCondition() -> FilterCondition? {
        guard !column.isEmpty else { return nil }
        let cell: Cell = op.bindsValue ? (value.isEmpty ? .text("") : .text(value)) : .null
        return FilterCondition(column: column, op: op, value: cell)
    }
}
