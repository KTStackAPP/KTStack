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

    private static let cellFont: NSFont = .monospacedSystemFont(ofSize: 12, weight: .regular)
    private static let nullFont: NSFont = .monospacedSystemFont(ofSize: 11, weight: .light)

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
        field.translatesAutoresizingMaskIntoConstraints = false
        addSubview(field)
        NSLayoutConstraint.activate([
            field.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            field.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            field.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
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
        switch highlight {
        case .none:
            return nil
        case .modified:
            return NSColor.systemOrange.withAlphaComponent(0.18)
        case .inserted:
            return NSColor.systemGreen.withAlphaComponent(0.18)
        case .deleted:
            return NSColor.systemRed.withAlphaComponent(0.18)
        }
    }
}
