import KTPluginKit
import SwiftUI

struct V2ExplainSheet: View {
    @ObservedObject var vm: DatabaseV2ViewModel
    let result: ExplainResult

    var body: some View {
        VStack(spacing: 0) {
            header
            content
        }
        .frame(width: 680, height: 480)
        .background(KTEditorTheme.window)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "list.bullet.indent").font(.system(size: 12)).foregroundStyle(KTEditorTheme.accent)
            Text("Query Plan").font(.jbMono(13)).foregroundStyle(KTEditorTheme.label)
            Spacer()
            V2Button(title: "Done") { vm.explainSheet = nil }
        }
        .padding(.horizontal, 16).padding(.vertical, 11)
        .overlay(alignment: .bottom) { Divider().overlay(KTEditorTheme.separator) }
    }

    @ViewBuilder
    private var content: some View {
        if let error = result.error {
            message(error, tint: KTEditorTheme.Status.error, icon: "xmark.circle.fill")
        } else if let tree = result.tree, !tree.isEmpty {
            ScrollView([.vertical, .horizontal]) {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(tree) { node in
                        ExplainNodeRow(node: node, depth: 0)
                    }
                }
                .padding(16)
            }
        } else if let raw = result.raw {
            KTDataGrid(result: raw)
        } else {
            message("No plan returned.", tint: KTEditorTheme.label2, icon: "info.circle")
        }
    }

    private func message(_ text: String, tint: Color, icon: String) -> some View {
        VStack {
            Spacer()
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 12))
                Text(text).font(.jbMono(12))
            }
            .foregroundStyle(tint)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

private struct ExplainNodeRow: View {
    let node: ExplainNode
    let depth: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.turn.down.right")
                    .font(.system(size: 9))
                    .foregroundStyle(KTEditorTheme.label3)
                    .opacity(depth == 0 ? 0 : 1)
                Text(node.text)
                    .font(.jbMono(11))
                    .foregroundStyle(KTEditorTheme.label)
                    .fixedSize(horizontal: true, vertical: false)
            }
            .padding(.leading, CGFloat(depth) * 18)
            ForEach(node.children) { child in
                ExplainNodeRow(node: child, depth: depth + 1)
            }
        }
    }
}
