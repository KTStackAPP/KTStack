import AppKit

extension KTDataGrid.Coordinator {
    func beginEditing(row: Int, column: Int) {
        let dataCol = column - 1
        guard let rowRef, dataCol >= 0, dataCol < result.columns.count, let ref = rowRef(row) else {
            editingRef = nil
            return
        }
        editingRef = (ref, result.columns[dataCol].name)
    }

    func commitEdit(row: Int, column: Int, text: String) {
        let pending = editingRef
        editingRef = nil
        guard let pending, let onCommitRowEdit else {
            onCommitEdit?(row, max(0, column - 1), text)
            return
        }
        if deferCommits {
            DispatchQueue.main.async { onCommitRowEdit(pending.ref, pending.column, text) }
        } else {
            onCommitRowEdit(pending.ref, pending.column, text)
        }
    }

    func settleOverlayBeforeRowsChange() {
        guard let editor = table?.overlayEditor, editor.isEditing else { return }
        deferCommits = true
        editor.dismiss(commit: editingRef != nil && onCommitRowEdit != nil)
        deferCommits = false
    }
}
