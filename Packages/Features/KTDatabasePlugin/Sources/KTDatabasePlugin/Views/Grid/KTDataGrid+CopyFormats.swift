import AppKit

extension KTDataGrid.Coordinator {
    @objc
    func copyJSON() {
        copyFormatted(.json)
    }

    @objc
    func copyMarkdown() {
        copyFormatted(.markdown)
    }

    func copyFormatted(_ format: GridCopyFormat) {
        let selected = table?.selectedRowIndexes ?? []
        let rows = selected.isEmpty ? Array(result.rows.indices) : Array(selected).sorted()
        let text = GridCopySerializer().serialize(
            result, rows: rows, columns: Array(result.columns.indices), format: format
        )
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}
