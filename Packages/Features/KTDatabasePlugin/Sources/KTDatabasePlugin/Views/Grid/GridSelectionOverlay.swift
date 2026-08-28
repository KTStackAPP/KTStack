import AppKit

/// Vẽ vùng chọn ô chữ nhật lên trên bảng; không nhận chuột để click vẫn xuống table.
final class GridSelectionOverlay: NSView {
    var selectionRect: NSRect? { didSet { if selectionRect != oldValue { needsDisplay = true } } }
    var focusRect: NSRect? { didSet { if focusRect != oldValue { needsDisplay = true } } }

    private static let fill = NSColor(srgbRed: 47 / 255, green: 107 / 255, blue: 255 / 255, alpha: 0.12)
    private static let stroke = NSColor(srgbRed: 47 / 255, green: 107 / 255, blue: 255 / 255, alpha: 0.85)

    override var isFlipped: Bool { true }
    override func hitTest(_: NSPoint) -> NSView? { nil }
    override func acceptsFirstMouse(for _: NSEvent?) -> Bool { false }

    override func draw(_: NSRect) {
        guard let selectionRect else { return }
        Self.fill.setFill()
        selectionRect.fill()
        Self.stroke.setStroke()
        let border = NSBezierPath(rect: selectionRect.insetBy(dx: 0.5, dy: 0.5))
        border.lineWidth = 1
        border.stroke()
        if let focusRect, focusRect != selectionRect {
            let focus = NSBezierPath(rect: focusRect.insetBy(dx: 1, dy: 1))
            focus.lineWidth = 2
            Self.stroke.setStroke()
            focus.stroke()
        }
    }
}
