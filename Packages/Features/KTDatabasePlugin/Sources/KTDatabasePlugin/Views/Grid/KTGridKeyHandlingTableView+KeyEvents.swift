import AppKit

extension KTGridKeyHandlingTableView {
    open override func keyDown(with event: NSEvent) {
        if overlayEditor.isEditing {
            super.keyDown(with: event)
            return
        }

        switch event.keyCode {
        case 126:
            moveActiveCell(rowDelta: -1, colDelta: 0)
        case 125:
            moveActiveCell(rowDelta: 1, colDelta: 0)
        case 123:
            moveActiveCell(rowDelta: 0, colDelta: -1)
        case 124:
            moveActiveCell(rowDelta: 0, colDelta: 1)
        case 48:
            let movement: KTCellEditorMovement = event.modifierFlags.contains(.shift) ? .backtab : .tab
            let current = activeCell ?? (row: 0, column: 0)
            if let next = KTCellMovementCoordinator.nextCell(
                from: current,
                movement: movement,
                rowCount: numberOfRows,
                columnCount: numberOfColumns
            ) {
                setActiveCell(row: next.row, column: next.column)
            }
        case 36, 76:
            if let active = activeCell {
                startEditing(row: active.row, column: active.column, selectAll: true)
            }
        case 51, 117:
            if let active = activeCell {
                onStageDeleteRow?(active.row)
            }
        case 53:
            clearActiveCell()
        default:
            if shouldHandleTypeToEdit(event: event) {
                if let active = activeCell, let char = event.characters?.first {
                    startEditing(row: active.row, column: active.column, selectAll: false, initialCharacter: char)
                    return
                }
            }
            super.keyDown(with: event)
        }
    }

    private func moveActiveCell(rowDelta: Int, colDelta: Int) {
        let current = activeCell ?? (row: 0, column: 0)
        let targetRow = max(0, min(numberOfRows - 1, current.row + rowDelta))
        let targetCol = max(0, min(numberOfColumns - 1, current.column + colDelta))
        guard targetRow >= 0, targetCol >= 0 else { return }
        setActiveCell(row: targetRow, column: targetCol)
    }

    private func shouldHandleTypeToEdit(event: NSEvent) -> Bool {
        guard !event.modifierFlags.contains(.command),
              !event.modifierFlags.contains(.control),
              let characters = event.characters,
              let scalar = characters.unicodeScalars.first,
              !CharacterSet.controlCharacters.contains(scalar),
              !(0xF700...0xF8FF).contains(scalar.value) else {
            return false
        }
        return true
    }

    open override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if overlayEditor.isEditing {
            return super.performKeyEquivalent(with: event)
        }

        guard event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command else {
            return super.performKeyEquivalent(with: event)
        }

        switch event.charactersIgnoringModifiers {
        case "n":
            onStageNewRecord?()
            return true
        case "s":
            onCommitStaged?()
            return true
        case "z":
            onUndoStaged?()
            return true
        case "c":
            onCopySelection?()
            return true
        case "v":
            onPasteSelection?()
            return true
        case "a":
            onSelectAllCells?()
            return true
        default:
            return super.performKeyEquivalent(with: event)
        }
    }
}
