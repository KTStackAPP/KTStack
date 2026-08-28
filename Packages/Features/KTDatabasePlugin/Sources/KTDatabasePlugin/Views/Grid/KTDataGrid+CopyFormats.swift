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
        copyCells(format: format)
    }
}
