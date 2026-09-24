import AppKit

open class KTGridKeyHandlingTableView: NSTableView {
    public let overlayEditor = KTCellOverlayEditor()
    public internal(set) var activeCell: (row: Int, column: Int)?

    public var canEditCell: ((Int, Int) -> Bool)?
    public var cellTextValue: ((Int, Int) -> String)?
    public var onCommitCell: ((Int, Int, String) -> Void)?
    public var onBeginEditing: ((Int, Int) -> Void)?
    public var onStageDeleteRow: ((Int) -> Void)?
    public var onStageNewRecord: (() -> Void)?
    public var onUndoStaged: (() -> Void)?
    public var onCommitStaged: (() -> Void)?
    public var onCopySelection: (() -> Void)?
    public var onPasteSelection: (() -> Void)?
    public var onSelectAllCells: (() -> Void)?
    public var onActiveCellChanged: (((row: Int, column: Int)?) -> Void)?
    public var onContextMenuRequested: ((Int, Int) -> Void)?

    public private(set) var menuRow: Int = -1
    public private(set) var menuColumn: Int = -1

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupEditorCallbacks()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupEditorCallbacks()
    }

    private func setupEditorCallbacks() {
        overlayEditor.onCommit = { [weak self] row, col, text in
            self?.onCommitCell?(row, col, text)
        }
        overlayEditor.onMovement = { [weak self] row, col, movement, _ in
            self?.handleMovement(fromRow: row, fromCol: col, movement: movement)
        }
    }

    open override var acceptsFirstResponder: Bool { true }

    public func setActiveCell(row: Int, column: Int) {
        guard row >= 0, row < numberOfRows, column >= 0, column < numberOfColumns else {
            clearActiveCell()
            return
        }
        activeCell = (row, column)
        selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        scrollRowToVisible(row)
        onActiveCellChanged?(activeCell)
        setNeedsDisplay(frameOfCell(atColumn: column, row: row))
    }

    public func clearActiveCell() {
        activeCell = nil
        onActiveCellChanged?(nil)
    }

    public func startEditing(row: Int, column: Int, selectAll: Bool = true, initialCharacter: Character? = nil) {
        guard canEditCell?(row, column) != false else { return }
        if overlayEditor.isEditing { overlayEditor.dismiss(commit: true) }
        onBeginEditing?(row, column)
        let text = cellTextValue?(row, column) ?? ""
        scrollRowToVisible(row)
        overlayEditor.show(
            in: self,
            row: row,
            column: column,
            value: text,
            selectAll: selectAll,
            initialCharacter: initialCharacter
        )
    }

    func handleMovement(fromRow: Int, fromCol: Int, movement: KTCellEditorMovement) {
        guard let next = KTCellMovementCoordinator.nextCell(
            from: (fromRow, fromCol),
            movement: movement,
            rowCount: numberOfRows,
            columnCount: numberOfColumns
        ) else { return }

        setActiveCell(row: next.row, column: next.column)
        if canEditCell?(next.row, next.column) != false {
            startEditing(row: next.row, column: next.column, selectAll: true)
        }
    }

    open override func mouseDown(with event: NSEvent) {
        if overlayEditor.isEditing {
            overlayEditor.dismiss(commit: true)
        }
        let point = convert(event.locationInWindow, from: nil)
        let clickRow = row(at: point)
        let clickCol = column(at: point)

        guard clickRow >= 0, clickCol >= 0 else {
            clearActiveCell()
            super.mouseDown(with: event)
            return
        }

        window?.makeFirstResponder(self)
        setActiveCell(row: clickRow, column: clickCol)

        if event.clickCount == 2 {
            startEditing(row: clickRow, column: clickCol, selectAll: true)
            return
        }

        super.mouseDown(with: event)
    }

    open override func menu(for event: NSEvent) -> NSMenu? {
        let point = convert(event.locationInWindow, from: nil)
        menuRow = row(at: point)
        menuColumn = column(at: point)
        if menuRow >= 0, menuColumn >= 0 {
            setActiveCell(row: menuRow, column: menuColumn)
            onContextMenuRequested?(menuRow, menuColumn)
        }
        return super.menu(for: event)
    }
}
