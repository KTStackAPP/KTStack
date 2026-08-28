import Foundation

public struct PasteGrid: Equatable, Sendable {
    public let rows: [[String]]

    public init(rows: [[String]]) {
        self.rows = rows
    }

    public var height: Int { rows.count }
    public var width: Int { rows.first?.count ?? 0 }
    public var isSingleCell: Bool { height == 1 && width == 1 }
}

public struct PastedCell: Equatable, Sendable {
    public let row: Int
    public let column: Int
    public let value: String

    public init(row: Int, column: Int, value: String) {
        self.row = row
        self.column = column
        self.value = value
    }
}

/// Where a paste lands: the anchor cell, the selected target rectangle, and the grid bounds it must
/// stay inside.
public struct PasteTarget: Equatable, Sendable {
    public let anchorRow: Int
    public let anchorColumn: Int
    public let targetRows: Int
    public let targetColumns: Int
    public let gridRowCount: Int
    public let gridColumnCount: Int

    public init(
        anchorRow: Int,
        anchorColumn: Int,
        targetRows: Int,
        targetColumns: Int,
        gridRowCount: Int,
        gridColumnCount: Int
    ) {
        self.anchorRow = anchorRow
        self.anchorColumn = anchorColumn
        self.targetRows = targetRows
        self.targetColumns = targetColumns
        self.gridRowCount = gridRowCount
        self.gridColumnCount = gridColumnCount
    }
}

public enum GridPasteError: Error, Equatable {
    case empty
    case ragged
    case shapeMismatch(expectedRows: Int, expectedColumns: Int, gotRows: Int, gotColumns: Int)
    case outOfBounds
}

/// Parses clipboard TSV/CSV into a grid and resolves it against a target rectangle. Nothing mutates
/// until the whole paste validates: a ragged grid or a shape that neither matches nor fills from a
/// single source cell is rejected before any cell changes.
public enum GridPasteParser {
    public static func parseTSV(_ text: String) throws -> PasteGrid {
        let lines = splitLines(text)
        guard !lines.isEmpty else { throw GridPasteError.empty }
        let rows = lines.map { $0.components(separatedBy: "\t") }
        return try normalized(rows)
    }

    public static func parseCSV(_ text: String) throws -> PasteGrid {
        let rows = try parseCSVRows(text)
        guard !rows.isEmpty else { throw GridPasteError.empty }
        return try normalized(rows)
    }

    /// Validates the parsed grid against the target rectangle and returns the concrete cell edits.
    /// A single source cell fills the whole target; otherwise the shape must match exactly.
    public static func resolve(_ grid: PasteGrid, into target: PasteTarget) throws -> [PastedCell] {
        guard grid.height > 0, grid.width > 0 else { throw GridPasteError.empty }
        guard target.anchorRow >= 0, target.anchorColumn >= 0 else { throw GridPasteError.outOfBounds }

        let rowCount = grid.isSingleCell ? target.targetRows : grid.height
        let columnCount = grid.isSingleCell ? target.targetColumns : grid.width

        if !grid.isSingleCell, target.targetRows > 1 || target.targetColumns > 1 {
            guard grid.height == target.targetRows, grid.width == target.targetColumns else {
                throw GridPasteError.shapeMismatch(
                    expectedRows: target.targetRows, expectedColumns: target.targetColumns,
                    gotRows: grid.height, gotColumns: grid.width
                )
            }
        }

        guard target.anchorRow + rowCount <= target.gridRowCount,
              target.anchorColumn + columnCount <= target.gridColumnCount else {
            throw GridPasteError.outOfBounds
        }

        var edits: [PastedCell] = []
        for rowOffset in 0..<rowCount {
            for columnOffset in 0..<columnCount {
                let value = grid.isSingleCell ? grid.rows[0][0] : grid.rows[rowOffset][columnOffset]
                edits.append(PastedCell(
                    row: target.anchorRow + rowOffset,
                    column: target.anchorColumn + columnOffset,
                    value: value
                ))
            }
        }
        return edits
    }

    private static func normalized(_ rows: [[String]]) throws -> PasteGrid {
        let width = rows.first?.count ?? 0
        guard width > 0 else { throw GridPasteError.empty }
        guard rows.allSatisfy({ $0.count == width }) else { throw GridPasteError.ragged }
        return PasteGrid(rows: rows)
    }

    private static func splitLines(_ text: String) -> [String] {
        var body = normalizedNewlines(text)
        if body.hasSuffix("\n") { body.removeLast() }
        guard !body.isEmpty else { return [] }
        return body.components(separatedBy: "\n")
    }

    private static func normalizedNewlines(_ text: String) -> String {
        text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
    }

    // RFC 4180-ish over unicode scalars (Swift folds "\r\n" into one Character, so scalars stay split):
    // double-quote wrapping, "" escapes a quote, delimiters/newlines allowed inside quotes.
    private static func parseCSVRows(_ text: String) throws -> [[String]] {
        let quote: Unicode.Scalar = "\""
        let comma: Unicode.Scalar = ","
        let lineFeed: Unicode.Scalar = "\n"
        let carriage: Unicode.Scalar = "\r"

        var rows: [[String]] = []
        var field = String.UnicodeScalarView()
        var row: [String] = []
        var insideQuotes = false
        let scalars = Array(text.unicodeScalars)
        var index = 0
        while index < scalars.count {
            let scalar = scalars[index]
            if insideQuotes {
                if scalar == quote {
                    if index + 1 < scalars.count, scalars[index + 1] == quote {
                        field.append(quote); index += 1
                    } else {
                        insideQuotes = false
                    }
                } else {
                    field.append(scalar)
                }
            } else {
                switch scalar {
                case quote: insideQuotes = true
                case comma: row.append(String(field)); field = String.UnicodeScalarView()
                case lineFeed:
                    row.append(String(field)); field = String.UnicodeScalarView()
                    rows.append(row); row = []
                case carriage: break
                default: field.append(scalar)
                }
            }
            index += 1
        }
        row.append(String(field))
        rows.append(row)
        // Bỏ dòng rỗng cuối do newline kết thúc.
        if rows.count > 1, rows.last == [""] { rows.removeLast() }
        return rows
    }
}
