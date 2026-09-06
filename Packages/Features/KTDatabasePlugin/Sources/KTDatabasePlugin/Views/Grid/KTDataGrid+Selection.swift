import AppKit

extension KTDataGrid.Coordinator {
    func makeContextMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(withTitle: "Copy", action: #selector(copyTSV), keyEquivalent: "")
        menu.addItem(withTitle: "Copy with Headers", action: #selector(copyTSVWithHeaders), keyEquivalent: "")
        menu.addItem(withTitle: "Copy as CSV", action: #selector(copyCSV), keyEquivalent: "")
        menu.addItem(withTitle: "Copy as JSON", action: #selector(copyJSON), keyEquivalent: "")
        menu.addItem(withTitle: "Copy as Markdown", action: #selector(copyMarkdown), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Set NULL", action: #selector(setSelectionNull), keyEquivalent: "")
        menu.addItem(withTitle: "Set Empty", action: #selector(setSelectionEmpty), keyEquivalent: "")
        menu.addItem(withTitle: "Set Current Time", action: #selector(setSelectionNow), keyEquivalent: "")
        menu.addItem(withTitle: "Set DEFAULT", action: #selector(setSelectionDefault), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Follow Foreign Key", action: #selector(followForeignKey), keyEquivalent: "")
        menu.addItem(withTitle: "Edit Row…", action: #selector(editRow), keyEquivalent: "")
        menu.items.forEach { $0.target = self }
        return menu
    }

    func handleContextMenu(row: Int, col: Int) {}

    @objc private func followForeignKey() {
        guard let table, table.menuRow >= 0, table.menuRow < result.rows.count,
              let column = dataIndex(of: table.tableColumns[table.menuColumn]),
              column < result.columns.count else { return }
        onNavigateFK?(table.menuRow, column)
    }

    @objc func copyTSV() {
        copySelectedRows(includeHeaders: false, asCSV: false)
    }

    @objc func copyTSVWithHeaders() {
        copySelectedRows(includeHeaders: true, asCSV: false)
    }

    @objc func copyCSV() {
        copySelectedRows(includeHeaders: true, asCSV: true)
    }

    @objc private func editRow() {
        guard let onActivate, let active = table?.activeCell, active.row < result.rows.count else { return }
        onActivate(active.row)
    }

    func validateMenuItem(_ item: NSMenuItem) -> Bool {
        guard let action = item.action else { return true }
        let setEditActions: [Selector] = [
            #selector(setSelectionNull), #selector(setSelectionEmpty),
            #selector(setSelectionNow), #selector(setSelectionDefault)
        ]
        if setEditActions.contains(action) {
            return onSetEdit != nil && table?.activeCell != nil
        }
        if item.action == #selector(editRow) {
            return onActivate != nil && table?.activeCell != nil
        }
        if item.action == #selector(followForeignKey) {
            guard onNavigateFK != nil, let table,
                  table.menuRow >= 0, table.menuRow < result.rows.count,
                  table.menuColumn >= 0, table.menuColumn < table.tableColumns.count,
                  let column = dataIndex(of: table.tableColumns[table.menuColumn]),
                  column < result.columns.count else { return false }
            return foreignKeyColumns.contains(result.columns[column].name)
                && result.rows[table.menuRow][column] != .null
        }
        return true
    }

    func copySelectedRows(includeHeaders: Bool, asCSV: Bool) {
        let activeRow = table?.activeCell?.row
        let indices: [Int]? = activeRow.map { [$0] }
        let text = asCSV
            ? QueryResultTextSerializer.csv(result, rows: indices, includeHeaders: includeHeaders)
            : QueryResultTextSerializer.tsv(result, rows: indices, includeHeaders: includeHeaders)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    @objc func setSelectionNull() { applyEditToActiveCell(.null) }
    @objc func setSelectionEmpty() { applyEditToActiveCell(.empty) }
    @objc func setSelectionNow() { applyEditToActiveCell(.now) }
    @objc func setSelectionDefault() { applyEditToActiveCell(.default) }

    private func applyEditToActiveCell(_ edit: CellEdit) {
        guard let onSetEdit, let active = table?.activeCell,
              active.row < result.rows.count, active.column > 0,
              let col = dataIndex(of: table?.tableColumns[active.column]),
              col < result.columns.count,
              editableColumns.contains(result.columns[col].name) else { return }
        onSetEdit(active.row, col, edit)
    }

    func gridSelectAll() {
        table?.selectAll(nil)
    }

    func gridPaste() {
        guard let onPaste, !editableColumns.isEmpty,
              let active = table?.activeCell,
              let string = NSPasteboard.general.string(forType: .string), !string.isEmpty else { return }
        guard let grid = try? (string.contains("\t") ? GridPasteParser.parseTSV(string) : GridPasteParser.parseCSV(string)) else { return }
        let dataCol = max(0, active.column - 1)
        let target = PasteTarget(
            anchorRow: active.row,
            anchorColumn: dataCol,
            targetRows: grid.rows.count,
            targetColumns: grid.rows.first?.count ?? 1,
            gridRowCount: result.rows.count,
            gridColumnCount: result.columns.count
        )
        guard let cells = try? GridPasteParser.resolve(grid, into: target) else { return }
        let editable = cells.filter {
            $0.column < result.columns.count && editableColumns.contains(result.columns[$0.column].name)
        }
        guard !editable.isEmpty else { return }
        onPaste(editable)
    }

    func copyCells(format: GridCopyFormat) {
        let rows = table?.activeCell.map { [$0.row] } ?? Array(result.rows.indices)
        let text = GridCopySerializer().serialize(result, rows: rows, columns: Array(result.columns.indices), format: format)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}

final class GridPickContext: NSObject {
    let row: Int
    let column: Int
    let value: String

    init(row: Int, column: Int, value: String) {
        self.row = row
        self.column = column
        self.value = value
    }
}

final class GridSetPickContext: NSObject {
    let row: Int
    let column: Int
    let member: String
    let members: [String]

    init(row: Int, column: Int, member: String, members: [String]) {
        self.row = row
        self.column = column
        self.member = member
        self.members = members
    }
}
