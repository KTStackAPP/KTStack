import XCTest
@testable import KTDatabasePlugin

/// Bộ dựng WHERE tách từ V2FilterSheet: điều kiện hợp lệ + preview cho cả 3 dialect.
final class GridFilterModelSQLTests: XCTestCase {
    func testConditionsDropEmptyColumn() {
        let drafts = [
            EditableCondition(column: "id", op: .equals, value: "5"),
            EditableCondition(column: "", op: .equals, value: "x"),
            EditableCondition(column: "name", op: .contains, value: "ab"),
        ]
        let built = FilterDraft.conditions(drafts)
        XCTAssertEqual(built.count, 2)
        XCTAssertEqual(built.map(\.column), ["id", "name"])
    }

    func testNullOperatorNeedsNoValue() {
        let drafts = [EditableCondition(column: "deleted_at", op: .isNull, value: "")]
        let built = FilterDraft.conditions(drafts)
        XCTAssertEqual(built.count, 1)
        XCTAssertEqual(built.first?.op, .isNull)
    }

    func testPreviewWhereForEachDialect() {
        let drafts = [EditableCondition(column: "id", op: .equals, value: "5")]
        for kind in [DatabaseKind.mysql, .postgres, .sqlite] {
            let preview = FilterDraft.previewWhere(drafts, kind: kind)
            XCTAssertNotNil(preview, "preview should build for \(kind)")
            XCTAssertTrue(preview?.contains("id") ?? false, "preview should name the column for \(kind)")
        }
    }

    func testPreviewWhereEmptyDraftsIsNil() {
        XCTAssertNil(FilterDraft.previewWhere([], kind: .mysql))
    }

    func testMysqlQuotesWithBackticks() {
        let drafts = [EditableCondition(column: "id", op: .equals, value: "5")]
        let preview = FilterDraft.previewWhere(drafts, kind: .mysql)
        XCTAssertEqual(preview, "`id` = ?")
    }

    func testPostgresQuotesWithDoubleQuotes() {
        let drafts = [EditableCondition(column: "id", op: .equals, value: "5")]
        let preview = FilterDraft.previewWhere(drafts, kind: .postgres)
        XCTAssertEqual(preview, "\"id\" = $1")
    }
}
