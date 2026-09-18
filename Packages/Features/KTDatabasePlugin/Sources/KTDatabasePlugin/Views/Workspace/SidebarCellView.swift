import AppKit
import KTPluginKit

final class SidebarCellView: NSTableCellView {
    private let icon = NSImageView()
    private let label = NSTextField(labelWithString: "")
    private let count = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError()
    }

    private func setup() {
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.contentTintColor = NSColor.secondaryLabelColor
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 13)
        label.lineBreakMode = .byTruncatingTail
        label.textColor = NSColor.labelColor
        count.translatesAutoresizingMaskIntoConstraints = false
        count.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        count.textColor = NSColor.tertiaryLabelColor
        count.alignment = .right

        addSubview(icon)
        addSubview(label)
        addSubview(count)
        textField = label
        imageView = icon

        NSLayoutConstraint.activate([
            icon.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            icon.centerYAnchor.constraint(equalTo: centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 16),
            icon.heightAnchor.constraint(equalToConstant: 16),
            label.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 6),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            count.leadingAnchor.constraint(greaterThanOrEqualTo: label.trailingAnchor, constant: 6),
            count.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            count.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    func configure(node: SidebarNode) {
        label.stringValue = node.title
        let weight: NSFont.Weight = node.isGroup ? .semibold : .regular
        let size: CGFloat = node.isGroup ? 11 : 13
        label.font = .systemFont(ofSize: size, weight: weight)
        label.textColor = node.isGroup ? NSColor.secondaryLabelColor : NSColor.labelColor
        icon.image = NSImage(systemSymbolName: node.systemImage, accessibilityDescription: nil)
        icon.isHidden = node.isGroup
        if node.isGroup, let subtitle = node.subtitle, !subtitle.isEmpty {
            count.stringValue = subtitle
            count.isHidden = false
        } else {
            count.stringValue = ""
            count.isHidden = true
        }
    }
}
