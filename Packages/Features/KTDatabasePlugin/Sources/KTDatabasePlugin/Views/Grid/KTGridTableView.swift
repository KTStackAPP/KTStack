import AppKit

/// Cầu nối input từ table view về coordinator (chọn ô, di chuyển bàn phím, copy/paste).
protocol KTGridInput: AnyObject {
    func gridSelect(viewRow: Int, viewColumn: Int, extending: Bool)
    func gridExtend(viewRow: Int, viewColumn: Int)
    func gridDoubleClick(viewRow: Int, viewColumn: Int)
    func gridMoveFocus(rowDelta: Int, columnDelta: Int, extending: Bool)
    func gridSelectAll()
    func gridCopy()
    func gridPaste()
    func gridBeginEditFocus()
}

final class KTGridTableView: NSTableView {
    weak var input: KTGridInput?
    private(set) var menuRow = -1
    private(set) var menuColumn = -1

    override var acceptsFirstResponder: Bool { true }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let clickRow = row(at: point)
        let clickColumn = column(at: point)
        guard clickRow >= 0, clickColumn >= 0 else { return }
        window?.makeFirstResponder(self)
        if event.clickCount == 2 {
            input?.gridDoubleClick(viewRow: clickRow, viewColumn: clickColumn)
            return
        }
        let extending = event.modifierFlags.contains(.shift)
        input?.gridSelect(viewRow: clickRow, viewColumn: clickColumn, extending: extending)
    }

    override func mouseDragged(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let dragRow = row(at: point)
        let dragColumn = column(at: point)
        guard dragRow >= 0, dragColumn >= 0 else { return }
        input?.gridExtend(viewRow: dragRow, viewColumn: dragColumn)
    }

    override func keyDown(with event: NSEvent) {
        let extending = event.modifierFlags.contains(.shift)
        switch event.keyCode {
        case 126: input?.gridMoveFocus(rowDelta: -1, columnDelta: 0, extending: extending)
        case 125: input?.gridMoveFocus(rowDelta: 1, columnDelta: 0, extending: extending)
        case 123: input?.gridMoveFocus(rowDelta: 0, columnDelta: -1, extending: extending)
        case 124: input?.gridMoveFocus(rowDelta: 0, columnDelta: 1, extending: extending)
        case 36, 76: input?.gridBeginEditFocus()
        default: super.keyDown(with: event)
        }
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command else {
            return super.performKeyEquivalent(with: event)
        }
        switch event.charactersIgnoringModifiers {
        case "c": input?.gridCopy(); return true
        case "v": input?.gridPaste(); return true
        case "a": input?.gridSelectAll(); return true
        default: return super.performKeyEquivalent(with: event)
        }
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        let point = convert(event.locationInWindow, from: nil)
        menuRow = row(at: point)
        menuColumn = column(at: point)
        if menuRow >= 0, menuColumn >= 0 {
            input?.gridSelect(viewRow: menuRow, viewColumn: menuColumn, extending: false)
        }
        return super.menu(for: event)
    }
}

final class KTGridRowView: NSTableRowView {
    override func drawSelection(in _: NSRect) {}
}
