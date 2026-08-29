import KTPluginKit
import SwiftUI

/// Nội dung một tab query: chỉ hộp SQL + kết quả, không có Data/Structure/ER.
struct WorkspaceQueryPane: View {
    @ObservedObject var vm: DatabaseV2ViewModel

    var body: some View {
        V2QueryTabView(vm: vm)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(KTEditorTheme.content)
            .sheet(item: $vm.parameterPrompt) { prompt in
                V2ParameterSheet(vm: vm, prompt: prompt)
            }
            .sheet(item: $vm.activeQuerySheet) { sheet in
                switch sheet {
                case .history: V2HistorySheet(vm: vm)
                case .favorites: V2FavoritesSheet(vm: vm)
                }
            }
            .sheet(item: $vm.explainSheet) { result in
                V2ExplainSheet(vm: vm, result: result)
            }
            .alert(
                "Run this destructive statement?",
                isPresented: Binding(
                    get: { vm.destructivePrompt != nil },
                    set: { if !$0 { vm.cancelDestructiveRun() } }
                )
            ) {
                Button("Cancel", role: .cancel) { vm.cancelDestructiveRun() }
                Button("Run", role: .destructive) { Task { await vm.confirmDestructiveRun() } }
            } message: {
                Text(vm.destructivePrompt?.reason ?? "")
            }
    }
}
