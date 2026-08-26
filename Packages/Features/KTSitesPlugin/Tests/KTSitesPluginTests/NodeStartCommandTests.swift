import XCTest
@testable import KTSitesPlugin

final class NodeStartCommandTests: XCTestCase {
    private let fm = FileManager.default

    private func makeFolder(packageJSON: String?) throws -> URL {
        let folder = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("kt-node-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)
        if let packageJSON {
            try packageJSON.write(
                to: folder.appendingPathComponent("package.json"),
                atomically: true,
                encoding: .utf8
            )
        }
        return folder
    }

    func testSuggestsDevScriptOverStart() throws {
        let folder = try makeFolder(packageJSON: #"{"scripts": {"start": "node server.js", "dev": "vite"}}"#)
        defer { try? fm.removeItem(at: folder) }
        XCTAssertEqual(NodeStartCommand.suggested(at: folder), "npm run dev")
    }

    func testSuggestsStartWhenNoDevScript() throws {
        let folder = try makeFolder(packageJSON: #"{"scripts": {"start": "node server.js"}}"#)
        defer { try? fm.removeItem(at: folder) }
        XCTAssertEqual(NodeStartCommand.suggested(at: folder), "npm start")
    }

    func testNoSuggestionWhenNoUsableScript() throws {
        let folder = try makeFolder(packageJSON: #"{"scripts": {"build": "tsc"}}"#)
        defer { try? fm.removeItem(at: folder) }
        XCTAssertNil(NodeStartCommand.suggested(at: folder))
    }

    func testNoSuggestionWhenNoPackageJSON() throws {
        let folder = try makeFolder(packageJSON: nil)
        defer { try? fm.removeItem(at: folder) }
        XCTAssertNil(NodeStartCommand.suggested(at: folder))
    }
}
