import Foundation

public struct KTCellMovementCoordinator: Sendable {
    public static func nextCell(
        from current: (row: Int, column: Int),
        movement: KTCellEditorMovement,
        rowCount: Int,
        columnCount: Int
    ) -> (row: Int, column: Int)? {
        guard rowCount > 0, columnCount > 0 else { return nil }
        var row = current.row
        var column = current.column

        switch movement {
        case .tab:
            if column + 1 < columnCount {
                column += 1
            } else if row + 1 < rowCount {
                row += 1
                column = 0
            } else {
                return nil
            }
        case .backtab:
            if column - 1 >= 0 {
                column -= 1
            } else if row - 1 >= 0 {
                row -= 1
                column = columnCount - 1
            } else {
                return nil
            }
        case .up:
            if row - 1 >= 0 {
                row -= 1
            } else {
                return nil
            }
        case .down:
            if row + 1 < rowCount {
                row += 1
            } else {
                return nil
            }
        }
        return (row, column)
    }
}
