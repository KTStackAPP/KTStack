import AppKit
import XCTest
@testable import KTDatabasePlugin

final class SQLSyntaxHighlighterTests: XCTestCase {
    private func makeStorage(_ text: String) -> (NSTextStorage, SQLSyntaxHighlighter) {
        let highlighter = SQLSyntaxHighlighter()
        highlighter.keywords = ["SELECT", "FROM"]
        let storage = NSTextStorage(string: text)
        storage.delegate = highlighter
        highlighter.highlight(storage)
        return (storage, highlighter)
    }

    private func color(_ storage: NSTextStorage, at location: Int) -> NSColor? {
        storage.attribute(.foregroundColor, at: location, effectiveRange: nil) as? NSColor
    }

    func testEditOnPlainLineRecolorsKeywordOnThatLine() {
        let (storage, _) = makeStorage("SELECT 1\nx")
        storage.replaceCharacters(in: NSRange(location: 9, length: 1), with: "FROM")
        XCTAssertNotEqual(color(storage, at: 9), NSColor.labelColor)
        XCTAssertEqual(color(storage, at: 0), color(storage, at: 9))
    }

    func testRemovingClosingQuoteOfMultilineStringRecolorsEarlierLines() {
        let (storage, _) = makeStorage("SELECT 'a\nb' FROM t")
        XCTAssertNotEqual(color(storage, at: 8), NSColor.labelColor)
        storage.replaceCharacters(in: NSRange(location: 11, length: 1), with: "")
        XCTAssertEqual(color(storage, at: 8), NSColor.labelColor)
        XCTAssertNotEqual(color(storage, at: 12), NSColor.labelColor)
    }
}
