import SwiftUI
import AppKit
import KTStackKit

struct KTDataGrid: NSViewRepresentable {
    let result: QueryResult
    var selectedRow: Binding<Int?>? = nil
    var onActivate: ((Int) -> Void)? = nil
    var onNearEnd: (() -> Void)? = nil
    var sort: SortSpec? = nil
    var onSortColumn: ((String) -> Void)? = nil
    var editableColumns: Set<String> = []
    var onCommitEdit: ((Int, Int, String) -> Void)? = nil

    func makeCoordinator() -> Coordinator { Coordinator(result: result) }

    func makeNSView(context: Context) -> NSScrollView {
        let coordinator = context.coordinator
        let table = KTGridTableView()
        table.usesAlternatingRowBackgroundColors = true
        table.backgroundColor = .white
        table.gridStyleMask = []
        table.allowsColumnResizing = true
        table.allowsColumnReordering = false
        table.columnAutoresizingStyle = .noColumnAutoresizing
        table.rowHeight = 22
        table.intercellSpacing = NSSize(width: 0, height: 0)
        table.allowsEmptySelection = true
        table.allowsMultipleSelection = true
        table.dataSource = coordinator
        table.delegate = coordinator
        table.target = coordinator
        table.doubleAction = #selector(Coordinator.handleDoubleClick)
        table.onCopy = { [weak coordinator] in
            coordinator?.copySelectedRows(includeHeaders: false, asCSV: false)
        }
        table.menu = coordinator.makeContextMenu()
        coordinator.table = table
        coordinator.rebuildColumns(for: result)

        let scroll = NSScrollView()
        scroll.documentView = table
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = true
        scroll.drawsBackground = true
        scroll.backgroundColor = .white
        scroll.contentView.postsBoundsChangedNotifications = true
        coordinator.observe(scroll)
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        context.coordinator.selectedRow = selectedRow
        context.coordinator.onActivate = onActivate
        context.coordinator.onNearEnd = onNearEnd
        context.coordinator.sort = sort
        context.coordinator.onSortColumn = onSortColumn
        context.coordinator.editableColumns = editableColumns
        context.coordinator.onCommitEdit = onCommitEdit
        context.coordinator.apply(result)
    }

    static func dismantleNSView(_ scroll: NSScrollView, coordinator: Coordinator) {
        coordinator.stopObserving()
    }

    final class Coordinator: NSObject, NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate {
        private(set) var result: QueryResult
        weak var table: NSTableView?
        weak var scrollView: NSScrollView?
        var selectedRow: Binding<Int?>?
        var onActivate: ((Int) -> Void)?
        var onNearEnd: (() -> Void)?
        var sort: SortSpec?
        var onSortColumn: ((String) -> Void)?
        var editableColumns: Set<String> = []
        var onCommitEdit: ((Int, Int, String) -> Void)?
        private var nearEndRequested = false
        private weak var editingField: NSTextField?
        private var editingRow = -1
        private var editingColumn = -1
        private var committedEdit = false

        static let cellFont: NSFont =
            NSFont(name: "JetBrainsMono-Medium", size: 12.5)
            ?? .monospacedSystemFont(ofSize: 12, weight: .regular)
        static let textColor = NSColor(hexValue: 0x42424C)
        static let nullColor = NSColor(hexValue: 0xC0C0C8)
        static let editingColor = NSColor(hexValue: 0xFFF6CC)

        init(result: QueryResult) { self.result = result }

        deinit { NotificationCenter.default.removeObserver(self) }

        func observe(_ scroll: NSScrollView) {
            scrollView = scroll
            NotificationCenter.default.addObserver(
                self, selector: #selector(boundsDidChange),
                name: NSView.boundsDidChangeNotification, object: scroll.contentView)
        }

        func stopObserving() {
            NotificationCenter.default.removeObserver(self)
        }

        @objc private func boundsDidChange() {
            guard let scroll = scrollView, let table, !result.rows.isEmpty else { return }
            if editingField != nil { table.window?.makeFirstResponder(table) }
            let documentHeight = table.bounds.height
            let viewportHeight = scroll.contentView.bounds.height
            guard documentHeight > viewportHeight else { return }
            let fraction = scroll.contentView.documentVisibleRect.maxY / documentHeight
            if fraction <= 0.8 {
                nearEndRequested = false
                return
            }
            guard !nearEndRequested else { return }
            nearEndRequested = true
            onNearEnd?()
        }

        func makeContextMenu() -> NSMenu {
            let menu = NSMenu()
            menu.addItem(withTitle: "Copy", action: #selector(copyTSV), keyEquivalent: "")
            menu.addItem(withTitle: "Copy with Headers", action: #selector(copyTSVWithHeaders), keyEquivalent: "")
            menu.addItem(withTitle: "Copy as CSV", action: #selector(copyCSV), keyEquivalent: "")
            menu.addItem(.separator())
            menu.addItem(withTitle: "Edit Row…", action: #selector(editRow), keyEquivalent: "")
            menu.items.forEach { $0.target = self }
            return menu
        }

        @objc private func copyTSV() { copySelectedRows(includeHeaders: false, asCSV: false) }
        @objc private func copyTSVWithHeaders() { copySelectedRows(includeHeaders: true, asCSV: false) }
        @objc private func copyCSV() { copySelectedRows(includeHeaders: true, asCSV: true) }

        @objc private func editRow() {
            guard let onActivate, let row = table?.selectedRowIndexes.first,
                  row < result.rows.count else { return }
            onActivate(row)
        }

        func validateMenuItem(_ item: NSMenuItem) -> Bool {
            if item.action == #selector(editRow) {
                return onActivate != nil && !(table?.selectedRowIndexes.isEmpty ?? true)
            }
            return true
        }

        func copySelectedRows(includeHeaders: Bool, asCSV: Bool) {
            let selected = table?.selectedRowIndexes ?? []
            let indices: [Int]? = selected.isEmpty ? nil : Array(selected).sorted()
            let text = asCSV
                ? QueryResultTextSerializer.csv(result, rows: indices, includeHeaders: includeHeaders)
                : QueryResultTextSerializer.tsv(result, rows: indices, includeHeaders: includeHeaders)
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(text, forType: .string)
        }

        func apply(_ newResult: QueryResult) {
            let columnsChanged = newResult.columns != result.columns
            let rowCountChanged = newResult.rows.count != result.rows.count
            result = newResult
            if columnsChanged { rebuildColumns(for: newResult) }
            if rowCountChanged { nearEndRequested = false }
            table?.reloadData()
            updateSortIndicators()
        }

        func tableView(_ tableView: NSTableView, didClick tableColumn: NSTableColumn) {
            guard let onSortColumn else { return }
            onSortColumn(tableColumn.title)
        }

        private func updateSortIndicators() {
            guard let table else { return }
            for column in table.tableColumns {
                if let sort, column.title == sort.column {
                    table.setIndicatorImage(
                        NSImage(systemSymbolName: sort.ascending ? "chevron.up" : "chevron.down",
                                accessibilityDescription: nil),
                        in: column)
                    table.highlightedTableColumn = column
                } else {
                    table.setIndicatorImage(nil, in: column)
                }
            }
        }

        func rebuildColumns(for result: QueryResult) {
            guard let table else { return }
            for column in table.tableColumns { table.removeTableColumn(column) }
            for (index, meta) in result.columns.enumerated() {
                let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("col-\(index)"))
                column.title = meta.name
                column.minWidth = 60
                column.width = 150
                table.addTableColumn(column)
            }
        }

        func numberOfRows(in tableView: NSTableView) -> Int { result.rows.count }

        func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?,
                       row: Int) -> NSView? {
            guard let tableColumn,
                  let columnIndex = tableView.tableColumns.firstIndex(of: tableColumn),
                  row < result.rows.count,
                  columnIndex < result.rows[row].count else { return nil }

            let identifier = NSUserInterfaceItemIdentifier("cell")
            let field = (tableView.makeView(withIdentifier: identifier, owner: self) as? NSTextField)
                ?? Self.makeCell(identifier: identifier)

            field.delegate = self
            field.isEditable = false
            field.drawsBackground = false
            if let text = result.rows[row][columnIndex].displayText {
                field.stringValue = text
                field.textColor = Self.textColor
            } else {
                field.stringValue = "NULL"
                field.textColor = Self.nullColor
            }
            return field
        }

        func tableViewSelectionDidChange(_ notification: Notification) {
            guard let table else { return }
            let indexes = table.selectedRowIndexes
            selectedRow?.wrappedValue = indexes.count == 1 ? indexes.first : nil
        }

        @objc func handleDoubleClick() {
            guard let table, table.clickedRow >= 0, table.clickedRow < result.rows.count else { return }
            let row = table.clickedRow
            let column = table.clickedColumn
            if column >= 0, cellIsInlineEditable(row: row, column: column) {
                beginInlineEdit(row: row, column: column)
            } else {
                onActivate?(row)
            }
        }

        private func cellIsInlineEditable(row: Int, column: Int) -> Bool {
            guard onCommitEdit != nil, column < result.columns.count else { return false }
            guard editableColumns.contains(result.columns[column].name) else { return false }
            if case .blob = result.rows[row][column] { return false }
            return true
        }

        private func beginInlineEdit(row: Int, column: Int) {
            guard let table,
                  let field = table.view(atColumn: column, row: row, makeIfNecessary: true) as? NSTextField
            else { return }
            committedEdit = false
            editingRow = row
            editingColumn = column
            editingField = field
            let cell = result.rows[row][column]
            field.stringValue = cell.displayText ?? ""
            field.textColor = Self.textColor
            field.isEditable = true
            field.drawsBackground = true
            field.backgroundColor = Self.editingColor
            table.editColumn(column, row: row, with: nil, select: true)
        }

        func controlTextDidEndEditing(_ obj: Notification) {
            guard let field = obj.object as? NSTextField, field === editingField else { return }
            let row = editingRow, column = editingColumn
            let value = field.stringValue
            let cancelled = (obj.userInfo?["NSTextMovement"] as? Int) == NSTextMovement.cancel.rawValue
            field.isEditable = false
            field.drawsBackground = false
            editingField = nil
            editingRow = -1
            editingColumn = -1
            guard !cancelled, !committedEdit, row >= 0, column >= 0 else {
                table?.reloadData()
                return
            }
            committedEdit = true
            onCommitEdit?(row, column, value)
        }

        private static func makeCell(identifier: NSUserInterfaceItemIdentifier) -> NSTextField {
            let field = NSTextField(labelWithString: "")
            field.identifier = identifier
            field.lineBreakMode = .byTruncatingTail
            field.font = cellFont
            field.drawsBackground = false
            return field
        }
    }
}

final class KTGridTableView: NSTableView {
    var onCopy: (() -> Void)?

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command,
           event.charactersIgnoringModifiers == "c" {
            onCopy?()
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        let row = self.row(at: convert(event.locationInWindow, from: nil))
        if row >= 0, !selectedRowIndexes.contains(row) {
            selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        }
        return super.menu(for: event)
    }
}

private extension NSColor {
    convenience init(hexValue: UInt32) {
        self.init(srgbRed: CGFloat((hexValue >> 16) & 0xFF) / 255,
                  green: CGFloat((hexValue >> 8) & 0xFF) / 255,
                  blue: CGFloat(hexValue & 0xFF) / 255,
                  alpha: 1)
    }
}
