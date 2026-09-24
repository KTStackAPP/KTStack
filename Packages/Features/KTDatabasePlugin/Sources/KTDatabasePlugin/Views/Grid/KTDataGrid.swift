import AppKit
import SwiftUI

struct KTDataGrid: NSViewRepresentable {
    let result: QueryResult
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

    func makeCoordinator() -> Coordinator {
        Coordinator(result: result)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let coordinator = context.coordinator
        let table = KTGridKeyHandlingTableView()
        table.usesAlternatingRowBackgroundColors = false
        table.backgroundColor = Coordinator.gridBackground
        table.gridStyleMask = [.solidVerticalGridLineMask, .solidHorizontalGridLineMask]
        table.gridColor = Coordinator.gridLineColor
        table.allowsColumnResizing = true
        table.allowsColumnReordering = false
        table.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle
        table.rowHeight = 22
        table.intercellSpacing = NSSize(width: 0, height: 0)
        table.allowsEmptySelection = true
        table.allowsMultipleSelection = false
        table.dataSource = coordinator
        table.delegate = coordinator
        table.menu = coordinator.makeContextMenu()
        coordinator.table = table

        table.canEditCell = { [weak coordinator] row, col in
            coordinator?.cellIsInlineEditable(row: row, column: col) ?? false
        }
        table.cellTextValue = { [weak coordinator] row, col in
            coordinator?.cellDisplayText(row: row, column: col) ?? ""
        }
        table.onCommitCell = { [weak coordinator] row, col, text in
            coordinator?.commitEdit(row: row, column: col, text: text)
        }
        table.onBeginEditing = { [weak coordinator] row, col in
            coordinator?.beginEditing(row: row, column: col)
        }
        table.onActiveCellChanged = { [weak coordinator] active in
            coordinator?.handleActiveCellChanged(active)
        }
        table.onStageNewRecord = { [weak coordinator] in
            coordinator?.onStageNewRecord?()
        }
        table.onStageDeleteRow = { [weak coordinator] row in
            coordinator?.onStageDeleteRow?(row)
        }
        table.onUndoStaged = { [weak coordinator] in
            coordinator?.onUndoStaged?()
        }
        table.onCommitStaged = { [weak coordinator] in
            coordinator?.onCommitStaged?()
        }
        table.onCopySelection = { [weak coordinator] in
            coordinator?.copyTSV()
        }
        table.onPasteSelection = { [weak coordinator] in
            coordinator?.gridPaste()
        }
        table.onSelectAllCells = { [weak coordinator] in
            coordinator?.table?.selectAll(nil)
        }

        coordinator.rebuildColumns(for: result)

        let scroll = NSScrollView()
        scroll.documentView = table
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = true
        scroll.drawsBackground = true
        scroll.backgroundColor = Coordinator.gridBackground
        scroll.contentView.postsBoundsChangedNotifications = true
        coordinator.observe(scroll)
        return scroll
    }

    func updateNSView(_: NSScrollView, context: Context) {
        let coordinator = context.coordinator
        coordinator.selectedRow = selectedRow
        coordinator.onActivate = onActivate
        coordinator.onNearEnd = onNearEnd
        coordinator.onNearTop = onNearTop
        coordinator.rowNumberOffset = rowNumberOffset
        coordinator.sort = sort
        coordinator.onSortColumn = onSortColumn
        coordinator.editableColumns = editableColumns
        coordinator.onCommitEdit = onCommitEdit
        coordinator.rowRef = rowRef
        coordinator.onCommitRowEdit = onCommitRowEdit
        coordinator.foreignKeyColumns = foreignKeyColumns
        coordinator.onNavigateFK = onNavigateFK
        coordinator.onPaste = onPaste
        coordinator.onSetEdit = onSetEdit
        coordinator.onOpenEditor = onOpenEditor
        coordinator.columnEditors = columnEditors
        coordinator.deletedRowIndices = deletedRowIndices
        coordinator.draftRowIndex = draftRowIndex
        coordinator.modifiedCells = modifiedCells
        coordinator.onStageNewRecord = onStageNewRecord
        coordinator.onStageDeleteRow = onStageDeleteRow
        coordinator.onUndoStaged = onUndoStaged
        coordinator.onCommitStaged = onCommitStaged
        coordinator.apply(result)
    }

    static func dismantleNSView(_: NSScrollView, coordinator: Coordinator) {
        coordinator.stopObserving()
    }
}
