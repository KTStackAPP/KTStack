import SwiftUI
import KTStackKit

struct KTColumnFilterPopover: View {
    let columns: [String]
    let onAdd: (FilterCondition) -> Void
    let onClose: () -> Void

    @State private var column: String
    @State private var op: FilterOperator = .equals
    @State private var value: String = ""

    init(columns: [String],
         onAdd: @escaping (FilterCondition) -> Void,
         onClose: @escaping () -> Void) {
        self.columns = columns
        self.onAdd = onAdd
        self.onClose = onClose
        _column = State(initialValue: columns.first ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add Filter").font(.jbMono(13, .bold)).foregroundStyle(KTColor.ink)

            field("Column") {
                Picker("", selection: $column) {
                    ForEach(columns, id: \.self) { Text($0).font(.jbMono(12.5)).tag($0) }
                }
                .labelsHidden()
            }

            field("Condition") {
                Picker("", selection: $op) {
                    ForEach(FilterOperator.allCases, id: \.self) { op in
                        Text(Self.label(for: op)).font(.jbMono(12.5)).tag(op)
                    }
                }
                .labelsHidden()
            }

            if op.bindsValue {
                field("Value") {
                    TextField("", text: $value)
                        .textFieldStyle(.roundedBorder)
                        .font(.jbMono(12.5))
                }
            }

            HStack(spacing: 8) {
                Spacer()
                Button("Cancel") { onClose() }
                    .buttonStyle(.plain)
                    .font(.jbMono(12.5))
                    .foregroundStyle(KTColor.ink3)
                Button("Apply") {
                    onAdd(FilterCondition(column: column, op: op,
                                          value: op.bindsValue ? .text(value) : .null))
                    onClose()
                }
                .buttonStyle(.borderedProminent)
                .font(.jbMono(12.5, .medium))
                .disabled(column.isEmpty)
            }
        }
        .padding(16)
        .frame(width: 280)
    }

    private func field<Content: View>(_ title: String,
                                      @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.jbMono(11, .medium)).foregroundStyle(KTColor.muted)
            content()
        }
    }

    private static func label(for op: FilterOperator) -> String {
        switch op {
        case .equals:      return "equals"
        case .notEquals:   return "not equals"
        case .contains:    return "contains"
        case .greaterThan: return "greater than"
        case .lessThan:    return "less than"
        case .isNull:      return "is null"
        case .isNotNull:   return "is not null"
        }
    }
}
