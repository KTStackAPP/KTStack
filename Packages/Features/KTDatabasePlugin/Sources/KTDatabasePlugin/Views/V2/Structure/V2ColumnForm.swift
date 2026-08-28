import KTPluginKit
import SwiftUI

/// Primitive-typed mirror of `ColumnDraft` for SwiftUI binding (the enum default doesn't bind well).
/// Seeds from a draft, produces a draft; the `DefaultKind` picker maps to `ColumnDefault`.
struct ColumnFormState: Identifiable {
    let id: UUID
    var name: String
    var type: String
    var nullable: Bool
    var autoIncrement: Bool
    var onUpdate: Bool
    var defaultKind: DefaultKind
    var defaultText: String
    var charset: String
    var collation: String
    var comment: String
    var generatedEnabled: Bool
    var generatedExpr: String
    var generatedStored: Bool
    var isPrimaryKey: Bool
    private let originalName: String?

    enum DefaultKind: String, CaseIterable, Identifiable {
        case none = "No default"
        case null = "NULL"
        case value = "Value"
        case number = "Number"
        case currentTimestamp = "CURRENT_TIMESTAMP"
        case expression = "Expression"
        var id: String { rawValue }
    }

    init() {
        id = UUID()
        name = ""
        type = "VARCHAR(255)"
        nullable = true
        autoIncrement = false
        onUpdate = false
        defaultKind = .none
        defaultText = ""
        charset = ""
        collation = ""
        comment = ""
        generatedEnabled = false
        generatedExpr = ""
        generatedStored = true
        isPrimaryKey = false
        originalName = nil
    }

    init(_ draft: ColumnDraft, isPrimaryKey: Bool = false) {
        id = draft.id
        name = draft.name
        type = draft.type
        nullable = draft.isNullable
        autoIncrement = draft.isAutoIncrement
        onUpdate = draft.onUpdateCurrentTimestamp
        charset = draft.charset ?? ""
        collation = draft.collation ?? ""
        comment = draft.comment ?? ""
        generatedEnabled = draft.generated != nil
        generatedExpr = draft.generated?.expression ?? ""
        generatedStored = draft.generated?.kind == .stored
        self.isPrimaryKey = isPrimaryKey
        originalName = draft.originalName
        switch draft.defaultValue {
        case .none: defaultKind = .none; defaultText = ""
        case .null: defaultKind = .null; defaultText = ""
        case let .text(value): defaultKind = .value; defaultText = value
        case let .number(value): defaultKind = .number; defaultText = value
        case .currentTimestamp: defaultKind = .currentTimestamp; defaultText = ""
        case let .expression(value): defaultKind = .expression; defaultText = value
        }
    }

    var trimmedName: String { name.trimmingCharacters(in: .whitespaces) }

    // ON UPDATE CURRENT_TIMESTAMP chỉ hợp lệ trên cột TIMESTAMP/DATETIME.
    var supportsOnUpdate: Bool {
        let upper = type.uppercased()
        return upper.contains("TIMESTAMP") || upper.contains("DATETIME")
    }

    var isValid: Bool {
        !trimmedName.isEmpty && !type.trimmingCharacters(in: .whitespaces).isEmpty
    }

    func toDraft() -> ColumnDraft {
        ColumnDraft(
            id: id,
            name: trimmedName,
            type: type.trimmingCharacters(in: .whitespaces),
            isNullable: nullable,
            isAutoIncrement: autoIncrement,
            defaultValue: resolvedDefault,
            onUpdateCurrentTimestamp: onUpdate && supportsOnUpdate,
            charset: charset.isEmpty ? nil : charset,
            collation: collation.isEmpty ? nil : collation,
            comment: comment.isEmpty ? nil : comment,
            generated: generatedEnabled && !generatedExpr.isEmpty
                ? GeneratedColumn(expression: generatedExpr, kind: generatedStored ? .stored : .virtual)
                : nil,
            originalName: originalName
        )
    }

    private var resolvedDefault: ColumnDefault {
        switch defaultKind {
        case .none: .none
        case .null: .null
        case .value: .text(defaultText)
        case .number: .number(defaultText)
        case .currentTimestamp: .currentTimestamp
        case .expression: .expression(defaultText)
        }
    }
}

/// Typed editor for one column, shared by add-column, create-table rows and edit-column.
struct ColumnFormView: View {
    @Binding var state: ColumnFormState
    var showPrimaryKeyToggle: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                field("name", text: $state.name)
                field("type", text: $state.type).frame(width: 160)
            }
            HStack(spacing: 14) {
                Toggle("Nullable", isOn: $state.nullable).toggleStyle(.checkbox)
                Toggle("Auto increment", isOn: $state.autoIncrement).toggleStyle(.checkbox)
                if showPrimaryKeyToggle {
                    Toggle("Primary key", isOn: $state.isPrimaryKey).toggleStyle(.checkbox)
                }
                Spacer()
            }
            .font(.system(size: 12))
            defaultRow
            HStack(spacing: 8) {
                field("charset (optional)", text: $state.charset)
                field("collation (optional)", text: $state.collation)
            }
            field("comment (optional)", text: $state.comment)
            generatedRow
        }
    }

    private var defaultRow: some View {
        HStack(spacing: 8) {
            Picker("Default", selection: $state.defaultKind) {
                ForEach(ColumnFormState.DefaultKind.allCases) { Text($0.rawValue).tag($0) }
            }
            .labelsHidden()
            .frame(width: 170)
            if state.defaultKind == .value || state.defaultKind == .number || state.defaultKind == .expression {
                field(state.defaultKind == .expression ? "expression" : "value", text: $state.defaultText)
            }
            if state.supportsOnUpdate {
                Toggle("ON UPDATE", isOn: $state.onUpdate).toggleStyle(.checkbox).font(.system(size: 12))
            }
            Spacer()
        }
    }

    private var generatedRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle("Generated column", isOn: $state.generatedEnabled).toggleStyle(.checkbox).font(.system(size: 12))
            if state.generatedEnabled {
                HStack(spacing: 8) {
                    field("expression", text: $state.generatedExpr)
                    Picker("", selection: $state.generatedStored) {
                        Text("STORED").tag(true)
                        Text("VIRTUAL").tag(false)
                    }
                    .labelsHidden()
                    .frame(width: 110)
                }
            }
        }
    }

    private func field(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .textFieldStyle(.roundedBorder)
            .font(.jbMono(12.5))
    }
}
