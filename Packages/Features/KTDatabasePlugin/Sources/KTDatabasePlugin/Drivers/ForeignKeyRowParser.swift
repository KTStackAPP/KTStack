import Foundation

public enum ForeignKeyRowParser {
    // Cột 0-4: from/to + tên. Cột 5/6 (tùy chọn): UPDATE_RULE, DELETE_RULE round-trip từ server.
    public static func parseRelational(_ rows: [[Cell]]) -> [ForeignKeyRelation] {
        rows.compactMap { row in
            guard row.count >= 4,
                  let fromTable = row[0].displayText, !fromTable.isEmpty,
                  let fromColumn = row[1].displayText, !fromColumn.isEmpty,
                  let toTable = row[2].displayText, !toTable.isEmpty,
                  let toColumn = row[3].displayText, !toColumn.isEmpty
            else { return nil }
            let name = row.count >= 5 ? row[4].displayText : nil
            let onUpdate = row.count >= 6 ? FKAction(rawValue: row[5].displayText ?? "") : nil
            let onDelete = row.count >= 7 ? FKAction(rawValue: row[6].displayText ?? "") : nil
            return ForeignKeyRelation(
                fromTable: fromTable,
                fromColumn: fromColumn,
                toTable: toTable,
                toColumn: toColumn,
                constraintName: name?.isEmpty == false ? name : nil,
                onDelete: onDelete,
                onUpdate: onUpdate
            )
        }
    }
}
