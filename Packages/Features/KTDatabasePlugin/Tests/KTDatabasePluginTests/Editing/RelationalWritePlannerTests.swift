import XCTest
@testable import KTDatabasePlugin

final class RelationalWritePlannerTests: XCTestCase {
    private let planner = RelationalWritePlanner(
        dialect: SQLDialect.forKind(.mysql),
        schema: "shop",
        table: "orders"
    )

    private func pk(_ value: Int64) -> RowIdentity {
        RowIdentity(key: [ColumnValue(column: "id", value: .int(value))], source: .primaryKey)
    }

    func testInsertStep() throws {
        let steps = try planner.plan([.insert(values: [
            ColumnValue(column: "name", value: .text("A")),
            ColumnValue(column: "qty", value: .int(2)),
        ])])
        XCTAssertEqual(steps.count, 1)
        XCTAssertEqual(steps[0].statement.sql, "INSERT INTO `shop`.`orders` (`name`, `qty`) VALUES (?, ?)")
        XCTAssertEqual(steps[0].statement.binds, [.text("A"), .int(2)])
        XCTAssertEqual(steps[0].expectedAffected, 1)
        XCTAssertNil(steps[0].noOpKeyCheck)
    }

    func testUpdateStepCarriesKeyCheck() throws {
        let steps = try planner.plan([.update(
            identity: pk(9),
            changes: [ColumnValue(column: "name", value: .text("B"))]
        )])
        XCTAssertEqual(steps[0].statement.sql, "UPDATE `shop`.`orders` SET `name` = ? WHERE `id` = ?")
        XCTAssertEqual(steps[0].statement.binds, [.text("B"), .int(9)])
        XCTAssertEqual(steps[0].noOpKeyCheck?.sql, "SELECT 1 FROM `shop`.`orders` WHERE `id` = ? LIMIT 1")
        XCTAssertEqual(steps[0].noOpKeyCheck?.binds, [.int(9)])
    }

    func testDeleteStep() throws {
        let steps = try planner.plan([.delete(identity: pk(4))])
        XCTAssertEqual(steps[0].statement.sql, "DELETE FROM `shop`.`orders` WHERE `id` = ?")
        XCTAssertEqual(steps[0].statement.binds, [.int(4)])
        XCTAssertEqual(steps[0].expectedAffected, 1)
    }

    func testPreviewIsRedacted() throws {
        let preview = try planner.preview([
            .delete(identity: pk(4)),
            .insert(values: [ColumnValue(column: "name", value: .text("secret"))]),
        ])
        XCTAssertEqual(preview.statements, [
            "DELETE FROM `shop`.`orders` WHERE `id` = ?",
            "INSERT INTO `shop`.`orders` (`name`) VALUES (?)",
        ])
        // Không rò giá trị: chỉ placeholder, đếm bind riêng.
        XCTAssertFalse(preview.statements.joined().contains("secret"))
        XCTAssertFalse(preview.statements.joined().contains("4"))
        XCTAssertEqual(preview.bindCount, 2)
    }

    func testKeylessUpdateThrows() {
        let noKey = RowIdentity(key: [], source: .primaryKey)
        XCTAssertThrowsError(try planner.plan([.update(identity: noKey, changes: [
            ColumnValue(column: "name", value: .text("X")),
        ])]))
    }
}
