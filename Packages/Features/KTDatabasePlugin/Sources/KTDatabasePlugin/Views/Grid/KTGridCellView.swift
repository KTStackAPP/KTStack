import AppKit

public enum KTGridCellHighlight: Sendable, Equatable {
    case none
    case modified
    case inserted
    case deleted
}

open class KTGridCellView: NSTableCellView {
    public var highlightState: KTGridCellHighlight = .none {
        didSet {
            if highlightState != oldValue {
                needsDisplay = true
            }
        }
    }

    private static let cellFont: NSFont =
        .init(name: "JetBrainsMono-Medium", size: 12.5)
            ?? .monospacedSystemFont(ofSize: 12, weight: .regular)
    private static let nullFont: NSFont =
        .init(name: "JetBrainsMono-Italic", size: 11.5)
            ?? .monospacedSystemFont(ofSize: 11, weight: .light)

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupViews()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }

    private func setupViews() {
        wantsLayer = true
        let field = NSTextField()
        field.isBordered = false
        field.drawsBackground = false
        field.isEditable = false
        field.isSelectable = false
        field.lineBreakMode = .byTruncatingTail
        field.font = Self.cellFont
        field.autoresizingMask = [.width, .height]
        field.frame = bounds.insetBy(dx: 4, dy: 1)
        addSubview(field)
        self.textField = field
    }

    public func configure(text: String, isNull: Bool, highlight: KTGridCellHighlight) {
        self.highlightState = highlight
        guard let field = textField else { return }

        if highlight == .deleted {
            let attr = NSMutableAttributedString(string: isNull ? "NULL" : text)
            let range = NSRange(location: 0, length: attr.length)
            attr.addAttribute(.font, value: isNull ? Self.nullFont : Self.cellFont, range: range)
            attr.addAttribute(.foregroundColor, value: NSColor.secondaryLabelColor, range: range)
            attr.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: range)
            attr.addAttribute(.strikethroughColor, value: NSColor.systemRed, range: range)
            field.attributedStringValue = attr
        } else if isNull {
            let attr = NSMutableAttributedString(string: "NULL")
            let range = NSRange(location: 0, length: 4)
            attr.addAttribute(.font, value: Self.nullFont, range: range)
            attr.addAttribute(.foregroundColor, value: NSColor.tertiaryLabelColor, range: range)
            field.attributedStringValue = attr
        } else {
            field.font = Self.cellFont
            field.textColor = .labelColor
            field.stringValue = text
        }
    }

    open override func draw(_ dirtyRect: NSRect) {
        if let bgColor = backgroundColor(for: highlightState) {
            bgColor.setFill()
            dirtyRect.fill()
        }
        super.draw(dirtyRect)
    }

    private func backgroundColor(for highlight: KTGridCellHighlight) -> NSColor? {
        let isDark = effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        switch highlight {
        case .none:
            return nil
        case .modified:
            return isDark
                ? NSColor(srgbRed: 0.24, green: 0.18, blue: 0.08, alpha: 1.0)
                : NSColor(srgbRed: 1.0, green: 0.95, blue: 0.80, alpha: 1.0)
        case .inserted:
            return isDark
                ? NSColor(srgbRed: 0.09, green: 0.20, blue: 0.12, alpha: 1.0)
                : NSColor(srgbRed: 0.83, green: 0.93, blue: 0.85, alpha: 1.0)
        case .deleted:
            return isDark
                ? NSColor(srgbRed: 0.24, green: 0.08, blue: 0.09, alpha: 1.0)
                : NSColor(srgbRed: 0.97, green: 0.84, blue: 0.85, alpha: 1.0)
        }
    }
}
