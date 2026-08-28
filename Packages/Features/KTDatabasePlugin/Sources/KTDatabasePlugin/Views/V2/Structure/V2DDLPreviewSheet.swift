import KTPluginKit
import SwiftUI

/// Show the queued DDL in execution order before it runs. Destructive statements are flagged, the
/// footer confirms with a destructive-aware label, and Apply runs them sequentially (stop-on-error).
struct V2DDLPreviewSheet: View {
    @ObservedObject var vm: DatabaseV2ViewModel
    let preview: DDLPreview

    private var hasDestructive: Bool { preview.statements.contains { $0.isDestructive } }

    var body: some View {
        VStack(spacing: 0) {
            V2SheetHeader(title: preview.title)
            if hasDestructive {
                destructiveBanner
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(preview.statements.enumerated()), id: \.element.id) { index, statement in
                        statementCard(index: index + 1, statement: statement)
                    }
                }
                .padding(18)
            }
            if let error = vm.ddlError {
                Text(error)
                    .font(.system(size: 12))
                    .foregroundStyle(KTEditorTheme.Status.error)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 18)
                    .padding(.bottom, 8)
            }
            Divider().overlay(KTEditorTheme.separator)
            footer
        }
        .frame(width: 560, height: 480)
        .background(KTEditorTheme.content)
    }

    private var destructiveBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 12))
            Text("This change drops schema objects and can't be undone.").font(.system(size: 12))
            Spacer()
        }
        .foregroundStyle(KTEditorTheme.Status.error)
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(KTEditorTheme.Status.error.opacity(0.08))
    }

    private func statementCard(index: Int, statement: DDLStatement) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text("\(index)")
                    .font(.jbMono(11, .bold))
                    .foregroundStyle(KTEditorTheme.onAccent)
                    .frame(width: 20, height: 20)
                    .background(
                        statement.isDestructive ? KTEditorTheme.Status.error : KTEditorTheme.accent,
                        in: Circle()
                    )
                Text(statement.summary).font(.system(size: 12.5)).foregroundStyle(KTEditorTheme.label)
                Spacer()
            }
            Text(statement.sql)
                .font(.jbMono(12))
                .foregroundStyle(KTEditorTheme.label2)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(KTEditorTheme.content2, in: RoundedRectangle(cornerRadius: 6))
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Spacer()
            Button("Cancel") { vm.cancelPreview() }
                .keyboardShortcut(.cancelAction)
            Button(hasDestructive ? "Apply (destructive)" : "Apply") {
                Task { await vm.applyPreview() }
            }
            .keyboardShortcut(.defaultAction)
            .disabled(vm.isDDLBusy)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }
}
