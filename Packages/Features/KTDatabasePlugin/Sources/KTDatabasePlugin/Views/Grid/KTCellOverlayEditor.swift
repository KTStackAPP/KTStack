import AppKit

public final class KTCellOverlayEditor: NSObject {
    private weak var tableView: NSTableView?
    private var containerView: OverlayContainerView?
    private var clipViewObserver: NSObjectProtocol?

    public private(set) var currentRow: Int = -1
    public private(set) var currentColumn: Int = -1
    public private(set) var isEditing: Bool = false

    public var onCommit: ((Int, Int, String) -> Void)?
    public var onMovement: ((Int, Int, KTCellEditorMovement, String) -> Void)?
    public var onDismiss: (() -> Void)?

    public override init() {
        super.init()
    }

    deinit {
        removeScrollObserver()
    }

    public func show(
        in tableView: NSTableView,
        row: Int,
        column: Int,
        value: String,
        selectAll: Bool = true,
        initialCharacter: Character? = nil
    ) {
        if isEditing {
            dismiss(commit: true)
        }

        guard row >= 0, row < tableView.numberOfRows,
              column >= 0, column < tableView.numberOfColumns else { return }

        self.tableView = tableView
        self.currentRow = row
        self.currentColumn = column
        self.isEditing = true

        let cellRect = tableView.frameOfCell(atColumn: column, row: row)
        let expandedRect = cellRect.insetBy(dx: -1, dy: -1)

        let container = OverlayContainerView(frame: expandedRect)
        let textView = OverlayTextView(frame: container.bounds.insetBy(dx: 3, dy: 1))
        textView.autoresizingMask = [.width, .height]
        textView.editor = self

        let initialText = initialCharacter.map(String.init) ?? value
        textView.string = initialText

        if initialCharacter != nil {
            textView.setSelectedRange(NSRange(location: initialText.count, length: 0))
        } else if selectAll {
            textView.selectAll(nil)
        } else {
            textView.setSelectedRange(NSRange(location: initialText.count, length: 0))
        }

        container.addSubview(textView)
        tableView.addSubview(container)
        self.containerView = container

        tableView.window?.makeFirstResponder(textView)
        addScrollObserver(for: tableView)
    }

    public func dismiss(commit: Bool) {
        guard isEditing else { return }
        isEditing = false

        removeScrollObserver()

        let row = currentRow
        let column = currentColumn
        let text = containerView?.textView?.string ?? ""

        let wasFirstResponder = containerView?.textView != nil &&
            tableView?.window?.firstResponder == containerView?.textView

        containerView?.removeFromSuperview()
        containerView = nil

        currentRow = -1
        currentColumn = -1

        if wasFirstResponder {
            tableView?.window?.makeFirstResponder(tableView)
        }

        if commit {
            onCommit?(row, column, text)
        }
        onDismiss?()
    }

    func commitAndMove(movement: KTCellEditorMovement) {
        guard isEditing else { return }
        let row = currentRow
        let column = currentColumn
        let text = containerView?.textView?.string ?? ""

        isEditing = false
        removeScrollObserver()

        containerView?.removeFromSuperview()
        containerView = nil

        currentRow = -1
        currentColumn = -1

        tableView?.window?.makeFirstResponder(tableView)
        onCommit?(row, column, text)
        onMovement?(row, column, movement, text)
        onDismiss?()
    }

    private func addScrollObserver(for tableView: NSTableView) {
        removeScrollObserver()
        guard let clipView = tableView.enclosingScrollView?.contentView else { return }
        clipView.postsBoundsChangedNotifications = true
        clipViewObserver = NotificationCenter.default.addObserver(
            forName: NSView.boundsDidChangeNotification,
            object: clipView,
            queue: .main
        ) { [weak self] _ in
            self?.dismiss(commit: true)
        }
    }

    private func removeScrollObserver() {
        if let observer = clipViewObserver {
            NotificationCenter.default.removeObserver(observer)
            clipViewObserver = nil
        }
    }
}
