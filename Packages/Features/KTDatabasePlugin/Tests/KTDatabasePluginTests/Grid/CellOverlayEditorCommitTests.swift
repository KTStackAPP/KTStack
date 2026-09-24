import AppKit
import XCTest
@testable import KTDatabasePlugin

@MainActor
final class CellOverlayEditorCommitTests: XCTestCase {
    private final class OneRowSource: NSObject, NSTableViewDataSource {
        func numberOfRows(in _: NSTableView) -> Int { 1 }
    }

    private let source = OneRowSource()

    private func makeTable() -> KTGridKeyHandlingTableView {
        let table = KTGridKeyHandlingTableView(frame: NSRect(x: 0, y: 0, width: 300, height: 200))
        table.addTableColumn(NSTableColumn(identifier: NSUserInterfaceItemIdentifier("c")))
        table.dataSource = source
        table.reloadData()
        return table
    }

    func testDismissWithoutChangesDoesNotCommit() {
        let table = makeTable()
        var commits: [String] = []
        table.overlayEditor.onCommit = { _, _, text in commits.append(text) }
        table.overlayEditor.show(in: table, row: 0, column: 0, value: "12345678901234567.89")
        table.overlayEditor.dismiss(commit: true)
        XCTAssertEqual(commits, [])
    }

    func testMovingAwayWithoutChangesDoesNotCommit() {
        let table = makeTable()
        var commits: [String] = []
        table.overlayEditor.onCommit = { _, _, text in commits.append(text) }
        table.overlayEditor.show(in: table, row: 0, column: 0, value: "unchanged")
        table.overlayEditor.commitAndMove(movement: .tab)
        XCTAssertEqual(commits, [])
    }

    func testTypedCharacterCommits() {
        let table = makeTable()
        var commits: [String] = []
        table.overlayEditor.onCommit = { _, _, text in commits.append(text) }
        table.overlayEditor.show(in: table, row: 0, column: 0, value: "old", initialCharacter: "n")
        table.overlayEditor.dismiss(commit: true)
        XCTAssertEqual(commits, ["n"])
        XCTAssertEqual(table.overlayEditor.originalText, "old")
    }
}
