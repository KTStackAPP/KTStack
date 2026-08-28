import AppKit

extension KTDataGrid.Coordinator: KTGridInput {
    func gridSelect(viewRow: Int, viewColumn: Int, extending: Bool) {
        guard viewRow >= 0, viewRow < result.rows.count, !result.columns.isEmpty else { return }
        if viewColumn == 0 {
            if extending, !selection.isEmpty {
                selection.extend(toRow: viewRow, column: result.columns.count - 1)
            } else {
                selection.selectRow(viewRow, columnCount: result.columns.count)
            }
        } else {
            let column = viewColumn - 1
            guard column < result.columns.count else { return }
            if extending, !selection.isEmpty {
                selection.extend(toRow: viewRow, column: column)
            } else {
                selection.selectCell(row: viewRow, column: column)
            }
        }
        refreshSelectionUI()
    }

    func gridExtend(viewRow: Int, viewColumn: Int) {
        guard viewRow >= 0, viewRow < result.rows.count, !result.columns.isEmpty else { return }
        let column = viewColumn == 0 ? result.columns.count - 1 : min(viewColumn - 1, result.columns.count - 1)
        selection.extend(toRow: viewRow, column: max(0, column))
        refreshSelectionUI()
    }

    func gridMoveFocus(rowDelta: Int, columnDelta: Int, extending: Bool) {
        guard !result.rows.isEmpty, !result.columns.isEmpty else { return }
        let current = selection.focus ?? GridCell(row: 0, column: 0)
        let row = min(max(0, current.row + rowDelta), result.rows.count - 1)
        let column = min(max(0, current.column + columnDelta), result.columns.count - 1)
        if extending, !selection.isEmpty {
            selection.extend(toRow: row, column: column)
        } else {
            selection.selectCell(row: row, column: column)
        }
        refreshSelectionUI()
        ensureVisible(row: row, column: column)
    }

    func gridSelectAll() {
        selection.selectAll(rowCount: result.rows.count, columnCount: result.columns.count)
        refreshSelectionUI()
    }

    func gridDoubleClick(viewRow: Int, viewColumn: Int) {
        gridSelect(viewRow: viewRow, viewColumn: viewColumn, extending: false)
        guard let column = dataIndex(ofViewColumn: viewColumn), cellIsInlineEditable(row: viewRow, column: column) else {
            if viewRow < result.rows.count { onActivate?(viewRow) }
            return
        }
        beginEditOrPicker(row: viewRow, viewColumn: viewColumn, dataColumn: column)
    }

    func gridBeginEditFocus() {
        guard let focus = selection.focus, focus.row < result.rows.count,
              cellIsInlineEditable(row: focus.row, column: focus.column) else { return }
        beginEditOrPicker(row: focus.row, viewColumn: focus.column + 1, dataColumn: focus.column)
    }

    private func beginEditOrPicker(row: Int, viewColumn: Int, dataColumn: Int) {
        let kind = editorKind(forColumn: dataColumn)
        switch kind {
        case let .enumeration(members) where !members.isEmpty:
            presentValuePicker(row: row, viewColumn: viewColumn, dataColumn: dataColumn, choices: members, isBool: false)
        case .bool:
            presentValuePicker(row: row, viewColumn: viewColumn, dataColumn: dataColumn, choices: ["1", "0"], isBool: true)
        case let .setMembership(members) where !members.isEmpty:
            presentSetPicker(row: row, viewColumn: viewColumn, dataColumn: dataColumn, members: members)
        default:
            beginInlineEdit(row: row, viewColumn: viewColumn, dataColumn: dataColumn)
        }
    }

    private func editorKind(forColumn dataColumn: Int) -> CellEditorKind {
        guard dataColumn < result.columns.count else { return .text }
        return columnEditors[result.columns[dataColumn].name] ?? .text
    }

    private func presentValuePicker(row: Int, viewColumn: Int, dataColumn: Int, choices: [String], isBool: Bool) {
        guard onSetEdit != nil, let table else { return }
        let menu = NSMenu()
        for choice in choices {
            let title = isBool ? (choice == "1" ? "true (1)" : "false (0)") : choice
            let item = NSMenuItem(title: title, action: #selector(didPickValue(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = GridPickContext(row: row, column: dataColumn, value: choice)
            menu.addItem(item)
        }
        let origin = table.frameOfCell(atColumn: viewColumn, row: row).origin
        menu.popUp(positioning: nil, at: origin, in: table)
    }

    @objc private func didPickValue(_ item: NSMenuItem) {
        guard let context = item.representedObject as? GridPickContext else { return }
        onSetEdit?(context.row, context.column, .value(context.value))
    }

    private func presentSetPicker(row: Int, viewColumn: Int, dataColumn: Int, members: [String]) {
        guard onSetEdit != nil, let table else { return }
        let current = currentSetMembers(row: row, dataColumn: dataColumn)
        let menu = NSMenu()
        for member in members {
            let item = NSMenuItem(title: member, action: #selector(didToggleSetMember(_:)), keyEquivalent: "")
            item.target = self
            item.state = current.contains(member) ? .on : .off
            item.representedObject = GridSetPickContext(row: row, column: dataColumn, member: member, members: members)
            menu.addItem(item)
        }
        let origin = table.frameOfCell(atColumn: viewColumn, row: row).origin
        menu.popUp(positioning: nil, at: origin, in: table)
    }

    private func currentSetMembers(row: Int, dataColumn: Int) -> Set<String> {
        guard row < result.rows.count, dataColumn < result.rows[row].count,
              let text = result.rows[row][dataColumn].displayText, !text.isEmpty else { return [] }
        return Set(text.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) })
    }

    @objc private func didToggleSetMember(_ item: NSMenuItem) {
        guard let context = item.representedObject as? GridSetPickContext else { return }
        var selected = currentSetMembers(row: context.row, dataColumn: context.column)
        if selected.contains(context.member) { selected.remove(context.member) } else { selected.insert(context.member) }
        let ordered = context.members.filter { selected.contains($0) }
        onSetEdit?(context.row, context.column, .value(ordered.joined(separator: ",")))
    }

    @objc func setSelectionNull() { applyEditToSelection(.null) }
    @objc func setSelectionEmpty() { applyEditToSelection(.empty) }
    @objc func setSelectionNow() { applyEditToSelection(.now) }

    private func applyEditToSelection(_ edit: CellEdit) {
        guard let onSetEdit, let rowRange = selection.rowRange, let columnRange = selection.columnRange else { return }
        for row in rowRange {
            for column in columnRange where column < result.columns.count
                && editableColumns.contains(result.columns[column].name) {
                onSetEdit(row, column, edit)
            }
        }
    }

    func gridCopy() { copyCells(format: .tsv) }

    func gridPaste() {
        guard let onPaste, !editableColumns.isEmpty,
              let rowRange = selection.rowRange, let columnRange = selection.columnRange,
              let string = NSPasteboard.general.string(forType: .string), !string.isEmpty else { return }
        guard let grid = try? (string.contains("\t") ? GridPasteParser.parseTSV(string) : GridPasteParser.parseCSV(string)) else { return }
        let target = PasteTarget(
            anchorRow: rowRange.lowerBound,
            anchorColumn: columnRange.lowerBound,
            targetRows: rowRange.count,
            targetColumns: columnRange.count,
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

    func refreshSelectionUI() {
        guard let table, let overlay else { return }
        overlay.frame = table.bounds
        guard let rowRange = selection.rowRange, let columnRange = selection.columnRange else {
            overlay.selectionRect = nil
            overlay.focusRect = nil
            selectedRow?.wrappedValue = nil
            return
        }
        overlay.selectionRect = cellRect(rows: rowRange, columns: columnRange)
        if let focus = selection.focus {
            overlay.focusRect = cellRect(rows: focus.row...focus.row, columns: focus.column...focus.column)
        }
        selectedRow?.wrappedValue = rowRange.count == 1 ? rowRange.lowerBound : nil
    }

    func clampSelection() {
        guard !selection.isEmpty else { return }
        if result.rows.isEmpty || result.columns.isEmpty {
            selection.clear()
        } else if let rowRange = selection.rowRange,
                  rowRange.upperBound >= result.rows.count || (selection.columnRange?.upperBound ?? 0) >= result.columns.count {
            selection.clear()
        }
        refreshSelectionUI()
    }

    private func cellRect(rows: ClosedRange<Int>, columns: ClosedRange<Int>) -> NSRect {
        guard let table else { return .zero }
        let top = table.frameOfCell(atColumn: columns.lowerBound + 1, row: rows.lowerBound)
        let bottom = table.frameOfCell(atColumn: columns.upperBound + 1, row: rows.upperBound)
        return top.union(bottom)
    }

    private func ensureVisible(row: Int, column: Int) {
        guard let table else { return }
        table.scrollRowToVisible(row)
        table.scrollColumnToVisible(column + 1)
    }

    func selectionRowsColumns() -> (rows: [Int], columns: [Int]) {
        if let rowRange = selection.rowRange, let columnRange = selection.columnRange {
            return (Array(rowRange), Array(columnRange))
        }
        return (Array(result.rows.indices), Array(result.columns.indices))
    }

    func copyCells(format: GridCopyFormat) {
        let (rows, columns) = selectionRowsColumns()
        let text = GridCopySerializer().serialize(result, rows: rows, columns: columns, format: format)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}

/// Ngữ cảnh (hàng, cột, giá trị) gắn vào item menu chọn giá trị enum/bool.
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

/// Ngữ cảnh cho picker set: thành viên vừa bấm và toàn bộ thứ tự thành viên để giữ đúng thứ tự khi join.
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
