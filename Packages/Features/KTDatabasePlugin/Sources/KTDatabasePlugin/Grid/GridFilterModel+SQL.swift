import Foundation

/// Bản dựng UI cho một điều kiện lọc: value là chuỗi, chuyển sang Cell khi Apply. Dùng cho
/// thanh filter inline (WorkspaceFilterBar).
struct EditableCondition: Identifiable {
    let id = UUID()
    var column: String
    var op: FilterOperator
    var value: String

    init(column: String, op: FilterOperator, value: String) {
        self.column = column
        self.op = op
        self.value = value
    }

    init(_ condition: FilterCondition) {
        column = condition.column
        op = condition.op
        value = condition.value.displayText ?? ""
    }

    func toCondition() -> FilterCondition? {
        guard !column.isEmpty else { return nil }
        let cell: Cell = op.bindsValue ? (value.isEmpty ? .text("") : .text(value)) : .null
        return FilterCondition(column: column, op: op, value: cell)
    }
}

enum FilterDraft {
    /// Drafts -> điều kiện hợp lệ (bỏ điều kiện thiếu cột).
    static func conditions(_ drafts: [EditableCondition]) -> [FilterCondition] {
        drafts.compactMap { $0.toCondition() }
    }

    /// WHERE preview (placeholder, không lộ literal) cho ô "SQL" thô của thanh filter.
    static func previewWhere(_ drafts: [EditableCondition], kind: DatabaseKind) -> String? {
        (try? SQLDialect.forKind(kind).whereClausePreview(conditions(drafts))) ?? nil
    }
}
