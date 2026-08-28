import Foundation

/// One data-cell address (data indices, independent of view columns).
public struct GridCell: Hashable, Sendable {
    public let row: Int
    public let column: Int

    public init(row: Int, column: Int) {
        self.row = row
        self.column = column
    }
}

/// A single rectangular cell selection held outside AppKit: an anchor plus a focus corner. Row and
/// column selections are rectangles spanning the given bounds. Pure value type so it unit-tests
/// without a table view.
public struct GridSelectionModel: Sendable, Equatable {
    public private(set) var anchor: GridCell?
    public private(set) var focus: GridCell?

    public init() {}

    public var isEmpty: Bool { anchor == nil }

    public mutating func selectCell(row: Int, column: Int) {
        let cell = GridCell(row: row, column: column)
        anchor = cell
        focus = cell
    }

    public mutating func extend(toRow row: Int, column: Int) {
        guard anchor != nil else {
            selectCell(row: row, column: column)
            return
        }
        focus = GridCell(row: row, column: column)
    }

    public mutating func selectRow(_ row: Int, columnCount: Int) {
        guard columnCount > 0 else { return clear() }
        anchor = GridCell(row: row, column: 0)
        focus = GridCell(row: row, column: columnCount - 1)
    }

    public mutating func selectColumn(_ column: Int, rowCount: Int) {
        guard rowCount > 0 else { return clear() }
        anchor = GridCell(row: 0, column: column)
        focus = GridCell(row: rowCount - 1, column: column)
    }

    public mutating func selectAll(rowCount: Int, columnCount: Int) {
        guard rowCount > 0, columnCount > 0 else { return clear() }
        anchor = GridCell(row: 0, column: 0)
        focus = GridCell(row: rowCount - 1, column: columnCount - 1)
    }

    public mutating func clear() {
        anchor = nil
        focus = nil
    }

    public var rowRange: ClosedRange<Int>? {
        guard let anchor, let focus else { return nil }
        return min(anchor.row, focus.row)...max(anchor.row, focus.row)
    }

    public var columnRange: ClosedRange<Int>? {
        guard let anchor, let focus else { return nil }
        return min(anchor.column, focus.column)...max(anchor.column, focus.column)
    }

    public func contains(row: Int, column: Int) -> Bool {
        guard let rowRange, let columnRange else { return false }
        return rowRange.contains(row) && columnRange.contains(column)
    }

    /// Cells in row-major order within the rectangle.
    public var cells: [GridCell] {
        guard let rowRange, let columnRange else { return [] }
        var result: [GridCell] = []
        for row in rowRange {
            for column in columnRange {
                result.append(GridCell(row: row, column: column))
            }
        }
        return result
    }
}
