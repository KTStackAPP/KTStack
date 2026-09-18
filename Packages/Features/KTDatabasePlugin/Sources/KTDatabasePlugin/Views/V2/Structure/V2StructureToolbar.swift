import KTPluginKit
import SwiftUI

enum StructureSheet: Identifiable {
    case newTable
    case addColumn
    case editColumn(String)
    case addIndex
    case addForeignKey
    case addCheck
    case tableOptions
    case createView
    case ddlSource

    var id: String {
        switch self {
        case .newTable: "newTable"
        case .addColumn: "addColumn"
        case let .editColumn(name): "editColumn-\(name)"
        case .addIndex: "addIndex"
        case .addForeignKey: "addForeignKey"
        case .addCheck: "addCheck"
        case .tableOptions: "tableOptions"
        case .createView: "createView"
        case .ddlSource: "ddlSource"
        }
    }
}

struct V2StructureToolbar: View {
    @ObservedObject var vm: DatabaseV2ViewModel
    let canEdit: Bool
    let isView: Bool
    let hasTable: Bool
    @Binding var confirmRename: Bool
    @Binding var renameText: String
    @Binding var confirmTruncate: Bool
    @Binding var confirmDropTable: Bool
    @Binding var confirmDropView: Bool
    let onOpenSheet: (StructureSheet) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                V2Button(title: "New Table", systemImage: "plus") { onOpenSheet(.newTable) }
                    .disabled(!canEdit)
                V2Button(title: "New View", systemImage: "eye") { onOpenSheet(.createView) }
                    .disabled(!canEdit)
                if hasTable {
                    Divider().frame(height: 18)
                    V2Button(title: "DDL Source", systemImage: "doc.text") { onOpenSheet(.ddlSource) }
                    if isView {
                        V2Button(title: "Drop View", kind: .danger) { confirmDropView = true }
                            .disabled(!canEdit)
                    } else {
                        tableActions
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .overlay(alignment: .bottom) { Divider().overlay(KTEditorTheme.separator) }
    }

    private var tableActions: some View {
        HStack(spacing: 8) {
            V2Button(title: "Add Column", systemImage: "plus.rectangle") { onOpenSheet(.addColumn) }
                .disabled(!canEdit)
            V2Button(title: "Add Index", systemImage: "number") { onOpenSheet(.addIndex) }
                .disabled(!canEdit)
            V2Button(title: "Add FK", systemImage: "link") { onOpenSheet(.addForeignKey) }
                .disabled(!canEdit)
            V2Button(title: "Add Check", systemImage: "checkmark.shield") { onOpenSheet(.addCheck) }
                .disabled(!canEdit)
            V2Button(title: "Options", systemImage: "gearshape") { onOpenSheet(.tableOptions) }
                .disabled(!canEdit)
            V2Button(title: "Rename", systemImage: "pencil") {
                renameText = vm.selectedTable?.name ?? ""
                confirmRename = true
            }
            .disabled(!canEdit)
            V2Button(title: "Truncate", kind: .danger) { confirmTruncate = true }
                .disabled(!canEdit)
            V2Button(title: "Drop Table", kind: .danger) { confirmDropTable = true }
                .disabled(!canEdit)
        }
    }
}
