import XCTest
@testable import KTDatabasePlugin

final class GridEditBufferTests: XCTestCase {
    private func pk(_ value: Int64) -> RowIdentity {
        RowIdentity(key: [ColumnValue(column: "id", value: .int(value))], source: .primaryKey)
    }

    func testStageUpdateProducesOperation() {
        let buffer = GridEditBuffer()
        buffer.stageUpdate(identity: pk(1), column: "name", value: .text("Alice"))
        XCTAssertTrue(buffer.hasPendingChanges)
        XCTAssertEqual(buffer.pendingCount, 1)
        XCTAssertEqual(
            buffer.operations(),
            [.update(identity: pk(1), changes: [ColumnValue(column: "name", value: .text("Alice"))])]
        )
    }

    func testMergesCellEditsOnSameRow() {
        let buffer = GridEditBuffer()
        buffer.stageUpdate(identity: pk(1), column: "name", value: .text("A"))
        buffer.stageUpdate(identity: pk(1), column: "age", value: .int(30))
        XCTAssertEqual(buffer.pendingCount, 1)
        guard case let .update(_, changes) = buffer.operations().first else { return XCTFail("expected update") }
        XCTAssertEqual(changes.map(\.column), ["age", "name"]) // sorted, deterministic
    }

    func testDeleteSupersedesPendingUpdate() {
        let buffer = GridEditBuffer()
        buffer.stageUpdate(identity: pk(1), column: "name", value: .text("A"))
        buffer.stageDelete(identity: pk(1))
        XCTAssertEqual(buffer.operations(), [.delete(identity: pk(1))])
    }

    func testUpdateOnDeletedRowIsIgnored() {
        let buffer = GridEditBuffer()
        buffer.stageDelete(identity: pk(1))
        buffer.stageUpdate(identity: pk(1), column: "name", value: .text("A"))
        XCTAssertEqual(buffer.operations(), [.delete(identity: pk(1))])
    }

    func testDraftInsert() {
        let buffer = GridEditBuffer()
        let id = buffer.stageInsert()
        buffer.setDraftValue(id, column: "name", value: .text("New"))
        XCTAssertEqual(buffer.operations(), [.insert(values: [ColumnValue(column: "name", value: .text("New"))])])
    }

    func testEmptyDraftProducesNoOperation() {
        let buffer = GridEditBuffer()
        _ = buffer.stageInsert()
        XCTAssertTrue(buffer.operations().isEmpty)
    }

    func testCommitOrderDeletesThenUpdatesThenInserts() {
        let buffer = GridEditBuffer()
        let draft = buffer.stageInsert()
        buffer.setDraftValue(draft, column: "name", value: .text("Z"))
        buffer.stageUpdate(identity: pk(2), column: "name", value: .text("U"))
        buffer.stageDelete(identity: pk(3))
        let kinds = buffer.operations().map { op -> String in
            switch op {
            case .delete: "delete"
            case .update: "update"
            case .insert: "insert"
            }
        }
        XCTAssertEqual(kinds, ["delete", "update", "insert"])
    }

    func testDeletesAreDeterministicallyOrdered() {
        let a = GridEditBuffer()
        a.stageDelete(identity: pk(3)); a.stageDelete(identity: pk(1)); a.stageDelete(identity: pk(2))
        let b = GridEditBuffer()
        b.stageDelete(identity: pk(2)); b.stageDelete(identity: pk(1)); b.stageDelete(identity: pk(3))
        XCTAssertEqual(a.operations(), b.operations())
    }

    func testUndoRedo() {
        let buffer = GridEditBuffer()
        buffer.stageUpdate(identity: pk(1), column: "name", value: .text("A"))
        XCTAssertTrue(buffer.canUndo)
        buffer.undo()
        XCTAssertFalse(buffer.hasPendingChanges)
        XCTAssertTrue(buffer.canRedo)
        buffer.redo()
        XCTAssertEqual(buffer.pendingCount, 1)
    }

    func testDiscardAllIsUndoable() {
        let buffer = GridEditBuffer()
        buffer.stageUpdate(identity: pk(1), column: "name", value: .text("A"))
        buffer.discardAll()
        XCTAssertFalse(buffer.hasPendingChanges)
        buffer.undo()
        XCTAssertEqual(buffer.pendingCount, 1)
    }

    func testMarkCommittedClearsUndoStack() {
        let buffer = GridEditBuffer()
        buffer.stageUpdate(identity: pk(1), column: "name", value: .text("A"))
        buffer.markCommitted()
        XCTAssertFalse(buffer.hasPendingChanges)
        XCTAssertFalse(buffer.canUndo)
        XCTAssertFalse(buffer.canRedo)
    }

    func testNoOpEditDoesNotPushUndo() {
        let buffer = GridEditBuffer()
        buffer.stageDelete(identity: pk(1))
        buffer.unstageDelete(identity: pk(2)) // removing a delete that isn't staged: no state change
        XCTAssertEqual(buffer.pendingCount, 1)
        buffer.undo()
        XCTAssertFalse(buffer.hasPendingChanges) // single real change undone
    }
}
