import AppKit
import KTPluginKit
import SwiftUI

extension KTDataGrid {
    final class Coordinator: NSObject, NSTableViewDataSource, NSTableViewDelegate {
        var result: QueryResult
        weak var table: KTGridKeyHandlingTableView?
        weak var scrollView: NSScrollView?
        var selectedRow: Binding<Int?>?
        var onActivate: ((Int) -> Void)?
        var onNearEnd: (() -> Void)?
        var onNearTop: (() -> Void)?
        var rowNumberOffset: Int = 0
        var sort: SortSpec?
        var onSortColumn: ((String) -> Void)?
        var editableColumns: Set<String> = []
        var onCommitEdit: ((Int, Int, String) -> Void)?
        var rowRef: ((Int) -> GridRowRef?)?
        var onCommitRowEdit: ((GridRowRef, String, String) -> Void)?
        var editingRef: (ref: GridRowRef, column: String)?
        var deferCommits = false
        var foreignKeyColumns: Set<String> = []
        var onNavigateFK: ((Int, Int) -> Void)?
        var onPaste: (([PastedCell]) -> Void)?
        var onSetEdit: ((Int, Int, CellEdit) -> Void)?
        var onOpenEditor: ((Int, Int) -> Void)?
        var columnEditors: [String: CellEditorKind] = [:]
        var deletedRowIndices: Set<Int> = []
        var draftRowIndex: Int?
        var modifiedCells: Set<CellCoord> = []
        var onStageNewRecord: (() -> Void)?
        var onStageDeleteRow: ((Int) -> Void)?
        var onUndoStaged: (() -> Void)?
        var onCommitStaged: (() -> Void)?

        var nearEndRequested = false
        var nearTopRequested = false
        var suppressScrollCallbacks = false
        var lastRowNumberOffset: Int = 0
        var contextMenuRow: Int = -1
        var contextMenuColumn: Int = -1
        var datePickerPopover: NSPopover?

        static let rownumIdentifier = "rownum"
        static let rownumFont: NSFont = .monospacedSystemFont(ofSize: 11, weight: .regular)
        static let headerFont: NSFont = .monospacedSystemFont(ofSize: 11.5, weight: .bold)
        static let headerBackground: NSColor = .windowBackgroundColor
        static let gridBackground: NSColor = .controlBackgroundColor
        static let gridLineColor: NSColor = .gridColor
        static let rownumColor: NSColor = .secondaryLabelColor
        static let defaultTextColor: NSColor = .labelColor
        init(result: QueryResult) {
            self.result = result
            super.init()
        }

        func numberOfRows(in tableView: NSTableView) -> Int {
            result.rows.count
        }

        func dataIndex(of tableColumn: NSTableColumn?) -> Int? {
            guard let tableColumn else { return nil }
            let raw = tableColumn.identifier.rawValue
            guard raw.hasPrefix("col-") else { return nil }
            return Int(raw.replacingOccurrences(of: "col-", with: ""))
        }

        func tableViewSelectionDidChange(_ notification: Notification) {
            guard let table else { return }
            let row = table.selectedRow
            if row >= 0 && row < result.rows.count {
                selectedRow?.wrappedValue = row
            } else {
                selectedRow?.wrappedValue = nil
            }
        }

        func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
            guard let tableColumn, row < result.rows.count else { return nil }

            if tableColumn.identifier.rawValue == Self.rownumIdentifier {
                let identifier = NSUserInterfaceItemIdentifier(Self.rownumIdentifier)
                let text = "\(rowNumberOffset + row + 1)"
                if let existing = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTextField {
                    existing.stringValue = text
                    return existing
                }
                let field = NSTextField(labelWithString: text)
                field.identifier = identifier
                field.font = Self.rownumFont
                field.textColor = Self.rownumColor
                field.alignment = .right
                return field
            }

            guard let columnIndex = Int(tableColumn.identifier.rawValue.replacingOccurrences(of: "col-", with: "")),
                  columnIndex < result.columns.count,
                  columnIndex < result.rows[row].count else { return nil }

            let cell = result.rows[row][columnIndex]
            let identifier = NSUserInterfaceItemIdentifier("cell")
            let cellView = (tableView.makeView(withIdentifier: identifier, owner: self) as? KTGridCellView)
                ?? KTGridCellView()
            cellView.identifier = identifier

            let highlight: KTGridCellHighlight
            if deletedRowIndices.contains(row) {
                highlight = .deleted
            } else if draftRowIndex == row {
                highlight = .inserted
            } else if modifiedCells.contains(CellCoord(row: row, column: columnIndex)) {
                highlight = .modified
            } else {
                highlight = .none
            }

            cellView.configure(text: cell.displayText ?? "", isNull: cell == .null, highlight: highlight)
            return cellView
        }

        func tableView(_: NSTableView, didClick tableColumn: NSTableColumn) {
            guard let onSortColumn, tableColumn.identifier.rawValue != Self.rownumIdentifier else { return }
            onSortColumn(tableColumn.title)
        }
    }
}
