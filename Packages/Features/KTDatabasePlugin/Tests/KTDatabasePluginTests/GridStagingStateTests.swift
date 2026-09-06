import XCTest
@testable import KTDatabasePlugin

final class GridStagingStateTests: XCTestCase {
    func testRowKeySingleColumn() {
        let row: [String: Cell] = [
            "id": .int(42),
            "name": .text("Alice")
        ]
        let key = RowKey.extract(from: row, primaryKeyColumns: ["id"])
        XCTAssertNotNil(key)
        XCTAssertEqual(key?.values["id"], .int(42))

        let key2 = RowKey.extract(from: row, primaryKeyColumns: ["id"])
        XCTAssertEqual(key, key2)
        XCTAssertEqual(key.hashValue, key2.hashValue)
    }

    func testRowKeyComposite() {
        let row: [String: Cell] = [
            "tenant_id": .text("acme"),
            "user_id": .int(101),
            "role": .text("admin")
        ]
        let key = RowKey.extract(from: row, primaryKeyColumns: ["tenant_id", "user_id"])
        XCTAssertNotNil(key)
        XCTAssertEqual(key?.values["tenant_id"], .text("acme"))
        XCTAssertEqual(key?.values["user_id"], .int(101))
    }

    func testRowKeyNullOrMissingReturnsNil() {
        let row1: [String: Cell] = ["id": .null]
        XCTAssertNil(RowKey.extract(from: row1, primaryKeyColumns: ["id"]))

        let row2: [String: Cell] = ["name": .text("Bob")]
        XCTAssertNil(RowKey.extract(from: row2, primaryKeyColumns: ["id"]))

        XCTAssertNil(RowKey.extract(from: ["id": .int(1)], primaryKeyColumns: []))
    }

    func testRowKeyFromCellsAndColumns() {
        let columns = [
            ColumnMeta(name: "id", typeName: "int"),
            ColumnMeta(name: "name", typeName: "text")
        ]
        let cells: [Cell] = [.int(99), .text("Charlie")]
        let key = RowKey.extract(from: cells, columns: columns, primaryKeyColumns: ["id"])
        XCTAssertNotNil(key)
        XCTAssertEqual(key?.values["id"], .int(99))
    }

    func testStagingStateEdit() {
        let state = KTGridStagingState()
        let key = RowKey(values: ["id": .int(1)])

        XCTAssertFalse(state.hasPendingChanges)
        XCTAssertEqual(state.pendingCount, 0)
        XCTAssertFalse(state.isCellModified(rowKey: key, column: "name"))

        state.stageEdit(key: key, column: "name", value: "New Name")
        XCTAssertTrue(state.hasPendingChanges)
        XCTAssertEqual(state.pendingCount, 1)
        XCTAssertTrue(state.isCellModified(rowKey: key, column: "name"))
        XCTAssertEqual(state.modifiedValue(rowKey: key, column: "name"), "New Name")

        state.clearEdit(key: key, column: "name")
        XCTAssertFalse(state.hasPendingChanges)
        XCTAssertEqual(state.pendingCount, 0)
    }

    func testStagingStateDelete() {
        let state = KTGridStagingState()
        let key = RowKey(values: ["id": .int(1)])

        state.stageEdit(key: key, column: "name", value: "Temp")
        state.stageDelete(key: key)

        XCTAssertTrue(state.isRowDeleted(rowKey: key))
        XCTAssertFalse(state.isCellModified(rowKey: key, column: "name"))
        XCTAssertEqual(state.pendingCount, 1)

        state.unstageDelete(key: key)
        XCTAssertFalse(state.isRowDeleted(rowKey: key))
        XCTAssertEqual(state.pendingCount, 0)
    }

    func testStagingStateInsert() {
        let state = KTGridStagingState()
        let id = state.stageInsert(values: ["name": "Draft User"])

        XCTAssertTrue(state.isDraftRow(id: id))
        XCTAssertEqual(state.pendingCount, 1)

        state.updateInsert(id: id, column: "name", value: "Updated Draft")
        XCTAssertEqual(state.insertedRows[id]?["name"], "Updated Draft")

        state.removeInsert(id: id)
        XCTAssertFalse(state.isDraftRow(id: id))
        XCTAssertFalse(state.hasPendingChanges)
    }

    func testStagingStateDiscardAll() {
        let state = KTGridStagingState()
        let key1 = RowKey(values: ["id": .int(1)])
        let key2 = RowKey(values: ["id": .int(2)])

        state.stageEdit(key: key1, column: "col", value: "val")
        state.stageDelete(key: key2)
        _ = state.stageInsert(values: ["col": "draft"])

        XCTAssertEqual(state.pendingCount, 3)
        state.discardAll()
        XCTAssertFalse(state.hasPendingChanges)
        XCTAssertEqual(state.pendingCount, 0)
    }
}
