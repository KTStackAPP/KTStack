import SwiftUI
import AppKit
import KTStackKit


final class CopyableTableView: NSTableView {
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

struct ResultsGridView: NSViewRepresentable {
    let result: QueryResult
    var selectedRow: Binding<Int?>? = nil
    var onDoubleClick: ((Int) -> Void)? = nil

    func makeCoordinator() -> Coordinator { Coordinator(result: result) }

    func makeNSView(context: Context) -> NSScrollView {
        let coordinator = context.coordinator
        let table = CopyableTableView()
        table.usesAlternatingRowBackgroundColors = true
        table.allowsColumnResizing = true
        table.columnAutoresizingStyle = .noColumnAutoresizing
        table.rowHeight = 20
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
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        context.coordinator.selectedRow = selectedRow
        context.coordinator.onDoubleClick = onDoubleClick
        context.coordinator.apply(result)
    }

    final class Coordinator: NSObject, NSTableViewDataSource, NSTableViewDelegate {
        private(set) var result: QueryResult
        weak var table: NSTableView?
        var selectedRow: Binding<Int?>?
        var onDoubleClick: ((Int) -> Void)?

        init(result: QueryResult) { self.result = result }

        func makeContextMenu() -> NSMenu {
            let menu = NSMenu()
            menu.addItem(withTitle: "Copy", action: #selector(copyTSV), keyEquivalent: "")
            menu.addItem(withTitle: "Copy with Headers", action: #selector(copyTSVWithHeaders), keyEquivalent: "")
            menu.addItem(withTitle: "Copy as CSV", action: #selector(copyCSV), keyEquivalent: "")
            menu.items.forEach { $0.target = self }
            return menu
        }

        @objc private func copyTSV() { copySelectedRows(includeHeaders: false, asCSV: false) }
        @objc private func copyTSVWithHeaders() { copySelectedRows(includeHeaders: true, asCSV: false) }
        @objc private func copyCSV() { copySelectedRows(includeHeaders: true, asCSV: true) }

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
            result = newResult
            if columnsChanged { rebuildColumns(for: newResult) }
            table?.reloadData()
        }

        func rebuildColumns(for result: QueryResult) {
            guard let table else { return }
            for column in table.tableColumns { table.removeTableColumn(column) }
            for (index, meta) in result.columns.enumerated() {
                let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("col-\(index)"))
                column.title = meta.name
                column.minWidth = 60
                column.width = 140
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


            if let text = result.rows[row][columnIndex].displayText {
                field.stringValue = text
                field.textColor = .labelColor
            } else {
                field.stringValue = "NULL"
                field.textColor = .tertiaryLabelColor
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
            onDoubleClick?(table.clickedRow)
        }

        private static func makeCell(identifier: NSUserInterfaceItemIdentifier) -> NSTextField {
            let field = NSTextField(labelWithString: "")
            field.identifier = identifier
            field.lineBreakMode = .byTruncatingTail
            field.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
            return field
        }
    }
}
