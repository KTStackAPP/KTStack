import AppKit

extension KTDataGrid.Coordinator {
    func presentDatePicker(row: Int, viewColumn: Int, dataColumn: Int, kind: CellEditorKind) {
        guard let onSetEdit, let table else { return }
        let seed = parseDate(row: row, dataColumn: dataColumn, kind: kind) ?? Date()
        let controller = GridDatePickerController(kind: kind, date: seed) { [weak self] picked in
            self?.datePickerPopover?.performClose(nil)
            self?.datePickerPopover = nil
            onSetEdit(row, dataColumn, .value(CellCoercion.timestampString(kind: kind, date: picked)))
        }
        let popover = NSPopover()
        popover.behavior = .transient
        popover.contentViewController = controller
        datePickerPopover = popover
        popover.show(relativeTo: table.frameOfCell(atColumn: viewColumn, row: row), of: table, preferredEdge: .maxY)
    }

    private func parseDate(row: Int, dataColumn: Int, kind: CellEditorKind) -> Date? {
        guard row < result.rows.count, dataColumn < result.rows[row].count,
              let text = result.rows[row][dataColumn].displayText, !text.isEmpty else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        switch kind {
        case .date: formatter.dateFormat = "yyyy-MM-dd"
        case .time: formatter.dateFormat = "HH:mm:ss"
        default: formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        }
        return formatter.date(from: text)
    }
}

/// Popover nhỏ chứa NSDatePicker cho cột date/datetime/time; nút Set mới stage giá trị đã format.
final class GridDatePickerController: NSViewController {
    private let kind: CellEditorKind
    private let initialDate: Date
    private let onSet: (Date) -> Void
    private let picker = NSDatePicker()

    init(kind: CellEditorKind, date: Date, onSet: @escaping (Date) -> Void) {
        self.kind = kind
        self.initialDate = date
        self.onSet = onSet
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("not supported") }

    override func loadView() {
        picker.datePickerStyle = kind == .time ? .textFieldAndStepper : .clockAndCalendar
        picker.datePickerElements = elements(for: kind)
        picker.dateValue = initialDate

        let button = NSButton(title: "Set", target: self, action: #selector(commit))
        button.keyEquivalent = "\r"
        button.bezelStyle = .rounded

        let stack = NSStackView(views: [picker, button])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 8
        stack.edgeInsets = NSEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        view = stack
    }

    private func elements(for kind: CellEditorKind) -> NSDatePicker.ElementFlags {
        switch kind {
        case .date: return .yearMonthDay
        case .time: return .hourMinuteSecond
        default: return [.yearMonthDay, .hourMinuteSecond]
        }
    }

    @objc private func commit() { onSet(picker.dateValue) }
}
