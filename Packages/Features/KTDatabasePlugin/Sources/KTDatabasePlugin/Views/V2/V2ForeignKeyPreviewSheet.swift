import KTPluginKit
import SwiftUI

struct V2ForeignKeyPreviewSheet: View {
    let preview: ForeignKeyPreview
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            if preview.result.rows.isEmpty {
                emptyState
            } else {
                KTDataGrid(result: preview.result)
                    .frame(minWidth: 560, minHeight: 320)
            }
        }
        .frame(width: 640, height: 420)
        .background(KTEditorTheme.window)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.turn.down.right")
                .font(.system(size: 12))
                .foregroundStyle(KTEditorTheme.accent)
            Text(preview.title)
                .font(.jbMono(13))
                .foregroundStyle(KTEditorTheme.label)
            Spacer()
            V2Button(title: "Close") { onClose() }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .overlay(alignment: .bottom) { Divider().overlay(KTEditorTheme.separator) }
    }

    private var emptyState: some View {
        VStack {
            Spacer()
            Text("No referenced row found")
                .font(.jbMono(12))
                .foregroundStyle(KTEditorTheme.label3)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(KTEditorTheme.content)
    }
}
