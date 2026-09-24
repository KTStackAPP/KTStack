import XCTest
@testable import KTDatabasePlugin

final class GridEditBufferCommitTests: XCTestCase {
    private let one = RowIdentity(key: [ColumnValue(column: "id", value: .int(1))], source: .primaryKey)
    private let two = RowIdentity(key: [ColumnValue(column: "id", value: .int(2))], source: .primaryKey)

    func testEditsStagedDuringCommitSurvive() {
        let buffer = GridEditBuffer()
        buffer.stageUpdate(identity: one, column: "name", value: .text("a"))
        let snapshot = buffer.commitSnapshot()
        buffer.stageUpdate(identity: two, column: "name", value: .text("b"))
        buffer.markCommitted(snapshot)
        XCTAssertNil(buffer.stagedUpdate(for: one))
        XCTAssertEqual(buffer.stagedUpdate(for: two), ["name": .text("b")])
        XCTAssertEqual(buffer.pendingCount, 1)
        XCTAssertFalse(buffer.canUndo)
    }

    func testValueChangedDuringCommitIsKept() {
        let buffer = GridEditBuffer()
        buffer.stageUpdate(identity: one, column: "name", value: .text("a"))
        let snapshot = buffer.commitSnapshot()
        buffer.stageUpdate(identity: one, column: "name", value: .text("a2"))
        buffer.markCommitted(snapshot)
        XCTAssertEqual(buffer.stagedUpdate(for: one), ["name": .text("a2")])
    }

    func testCommittedDeletesAndDraftsAreCleared() {
        let buffer = GridEditBuffer()
        buffer.stageDelete(identity: one)
        let draft = buffer.stageInsert()
        buffer.setDraftValue(draft, column: "name", value: .text("new"))
        let snapshot = buffer.commitSnapshot()
        buffer.stageDelete(identity: two)
        buffer.markCommitted(snapshot)
        XCTAssertFalse(buffer.isStagedDelete(one))
        XCTAssertTrue(buffer.isStagedDelete(two))
        XCTAssertEqual(buffer.operations().count, 1)
    }

    func testUntouchedBufferClearsEverything() {
        let buffer = GridEditBuffer()
        buffer.stageUpdate(identity: one, column: "name", value: .text("a"))
        buffer.markCommitted(buffer.commitSnapshot())
        XCTAssertFalse(buffer.hasPendingChanges)
    }
}
