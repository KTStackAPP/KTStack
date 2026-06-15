import SwiftUI
import KDWarmKit

struct QueryEditorView: View {
    @EnvironmentObject private var vm: DatabaseViewModel
    @State private var sql = "SELECT 1"

    private var canRun: Bool {
        vm.connection == .connected && !vm.isBusy
            && !sql.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VSplitView {
            editor
            results
        }
        .alert("Run this destructive statement?", isPresented: dangerousBinding,
               presenting: vm.pendingDangerousSQL) { _ in
            Button("Run anyway", role: .destructive) { Task { await vm.runSQL(sql, confirmed: true) } }
            Button("Cancel", role: .cancel) { vm.cancelDangerousSQL() }
        } message: { _ in
            Text(DestructiveGuard.evaluate(sql).reason
                 ?? "This statement may change or remove many rows.")
        }
    }

    private var dangerousBinding: Binding<Bool> {
        Binding(get: { vm.pendingDangerousSQL != nil },
                set: { if !$0 { vm.cancelDangerousSQL() } })
    }

    private var editor: some View {
        VStack(spacing: 0) {
            HStack {
                Text(vm.selectedDatabase.map { "Database: \($0)" } ?? "No database selected")
                    .font(KDFont.footnote).foregroundStyle(.secondary)
                Spacer()
                if vm.isBusy { ProgressView().controlSize(.small) }
                Button { Task { await vm.runSQL(sql) } } label: {
                    Label("Run", systemImage: "play.fill")
                }
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(!canRun)
            }
            .padding(KDSpacing.space2)
            Divider()
            TextEditor(text: $sql)
                .font(KDFont.mono)
                .frame(minHeight: 80)
        }
    }

    @ViewBuilder
    private var results: some View {
        if let error = vm.resultError, vm.resultSource == .query {
            EmptyStateView(symbol: "exclamationmark.triangle",
                           title: "SQL error", message: error)
        } else if let result = vm.result, vm.resultSource == .query {
            VStack(spacing: 0) {
                HStack {
                    Text("\(result.rowCount) rows · \(result.columns.count) columns")
                        .font(KDFont.footnote).foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(KDSpacing.space2)
                Divider()
                ResultsGridView(result: result)
            }
        } else {
            EmptyStateView(symbol: "terminal",
                           title: "Run a query",
                           message: "Type SQL above and press ⌘↩ to see results here.")
        }
    }
}
