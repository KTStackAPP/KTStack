import AppKit
import KTPluginKit

extension KTDataGrid.Coordinator {
    func apply(_ newResult: QueryResult) {
        let columnsChanged = newResult.columns != result.columns
        let rowCountChanged = newResult.rows.count != result.rows.count
        let contentChanged = columnsChanged || rowCountChanged || newResult.rows != result.rows
        let offsetDelta = rowNumberOffset - lastRowNumberOffset
        if contentChanged || offsetDelta != 0 { settleOverlayBeforeRowsChange() }
        result = newResult
        if columnsChanged { rebuildColumns(for: newResult) }
        if rowCountChanged || offsetDelta != 0 {
            nearEndRequested = false
            nearTopRequested = false
        }
        if contentChanged { table?.reloadData() }
        table?.shiftActiveCell(by: -offsetDelta)
        if offsetDelta != 0, let scroll = scrollView, let table {
            suppressScrollCallbacks = true
            var origin = scroll.contentView.bounds.origin
            origin.y = max(0, origin.y - CGFloat(offsetDelta) * table.rowHeight)
            scroll.contentView.scroll(to: origin)
            scroll.reflectScrolledClipView(scroll.contentView)
            suppressScrollCallbacks = false
        }
        lastRowNumberOffset = rowNumberOffset
        updateSortIndicators()
    }

    func rebuildColumns(for result: QueryResult) {
        guard let table else { return }
        for column in table.tableColumns {
            table.removeTableColumn(column)
        }
        let rownum = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(Self.rownumIdentifier))
        rownum.title = ""
        rownum.width = 50
        rownum.minWidth = 40
        rownum.maxWidth = 72
        rownum.headerCell.textColor = Self.rownumColor
        rownum.headerCell.drawsBackground = true
        rownum.headerCell.backgroundColor = Self.headerBackground
        table.addTableColumn(rownum)
        for (index, meta) in result.columns.enumerated() {
            let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("col-\(index)"))
            column.title = meta.name
            column.minWidth = 60
            column.width = 150
            column.headerCell.font = Self.headerFont
            column.headerCell.textColor = Self.defaultTextColor
            column.headerCell.drawsBackground = true
            column.headerCell.backgroundColor = Self.headerBackground
            table.addTableColumn(column)
        }
        table.sizeLastColumnToFit()
    }

    func updateSortIndicators() {
        guard let table else { return }
        for column in table.tableColumns {
            if let sort, column.title == sort.column {
                table.setIndicatorImage(
                    NSImage(
                        systemSymbolName: sort.ascending ? "chevron.up" : "chevron.down",
                        accessibilityDescription: nil
                    ),
                    in: column
                )
                table.highlightedTableColumn = column
            } else {
                table.setIndicatorImage(nil, in: column)
            }
        }
    }

    func observe(_ scroll: NSScrollView) {
        scrollView = scroll
        NotificationCenter.default.addObserver(
            self, selector: #selector(boundsDidChange),
            name: NSView.boundsDidChangeNotification, object: scroll.contentView
        )
    }

    func stopObserving() {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func boundsDidChange() {
        guard !suppressScrollCallbacks, let scroll = scrollView, let table, !result.rows.isEmpty else { return }
        let documentHeight = table.bounds.height
        let viewportHeight = scroll.contentView.bounds.height
        guard documentHeight > viewportHeight else { return }
        let visible = scroll.contentView.documentVisibleRect
        let topFraction = visible.minY / documentHeight
        if topFraction < 0.1, onNearTop != nil {
            if !nearTopRequested { nearTopRequested = true; onNearTop?() }
        } else {
            nearTopRequested = false
        }
        let fraction = visible.maxY / documentHeight
        if fraction <= 0.8 {
            nearEndRequested = false
            return
        }
        guard !nearEndRequested else { return }
        nearEndRequested = true
        onNearEnd?()
    }
}
