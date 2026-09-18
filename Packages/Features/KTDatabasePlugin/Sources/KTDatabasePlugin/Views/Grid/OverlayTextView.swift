import AppKit

final class OverlayContainerView: NSView {
    var textView: OverlayTextView? {
        subviews.first as? OverlayTextView
    }

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = NSColor.textBackgroundColor.cgColor
        layer?.borderColor = NSColor.controlAccentColor.cgColor
        layer?.borderWidth = 2
        layer?.cornerRadius = 3
        layer?.zPosition = 1000
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError()
    }
}

final class OverlayTextView: NSTextView {
    weak var editor: KTCellOverlayEditor?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        configure()
    }

    override init(frame frameRect: NSRect, textContainer container: NSTextContainer?) {
        super.init(frame: frameRect, textContainer: container)
        configure()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError()
    }

    private func configure() {
        isRichText = false
        importsGraphics = false
        isContinuousSpellCheckingEnabled = false
        drawsBackground = false
        font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        textColor = .labelColor
        insertionPointColor = .controlAccentColor
        textContainerInset = NSSize(width: 0, height: 2)
        textContainer?.lineFragmentPadding = 0
        isHorizontallyResizable = false
        isVerticallyResizable = true
    }
    override func resignFirstResponder() -> Bool {
        let resigned = super.resignFirstResponder()
        if resigned {
            editor?.dismiss(commit: true)
        }
        return resigned
    }


    override func insertTab(_ sender: Any?) {
        editor?.commitAndMove(movement: .tab)
    }

    override func insertBacktab(_ sender: Any?) {
        editor?.commitAndMove(movement: .backtab)
    }

    override func insertNewline(_ sender: Any?) {
        if let event = NSApp.currentEvent,
           event.modifierFlags.contains(.shift) || event.modifierFlags.contains(.option) {
            super.insertNewline(sender)
        } else {
            editor?.commitAndMove(movement: .down)
        }
    }

    override func cancelOperation(_ sender: Any?) {
        editor?.dismiss(commit: false)
    }

    override func moveUp(_ sender: Any?) {
        if KTCellEditorArrowExit.canExitUp(text: string, selectedRange: selectedRange()) {
            editor?.commitAndMove(movement: .up)
        } else {
            super.moveUp(sender)
        }
    }

    override func moveDown(_ sender: Any?) {
        if KTCellEditorArrowExit.canExitDown(text: string, selectedRange: selectedRange()) {
            editor?.commitAndMove(movement: .down)
        } else {
            super.moveDown(sender)
        }
    }
}
