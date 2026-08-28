import KTPluginKit
import SwiftUI

/// Read-only canonical DDL from the server (SHOW CREATE TABLE/VIEW), loaded on appear.
struct V2DDLSourceSheet: View {
    @ObservedObject var vm: DatabaseV2ViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            V2SheetHeader(title: "Create Statement")
            ScrollView {
                Text(vm.createTableDDL ?? "Loading…")
                    .font(.jbMono(12.5))
                    .foregroundStyle(KTEditorTheme.label)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(18)
            }
            Divider().overlay(KTEditorTheme.separator)
            HStack {
                Spacer()
                Button("Close") { dismiss() }.keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
        }
        .frame(width: 620, height: 480)
        .background(KTEditorTheme.content)
        .task { await vm.loadCreateTableDDL() }
    }
}
