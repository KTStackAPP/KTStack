import XCTest
@testable import KTStackKit

final class SiteInspectorNodeClassificationTests: XCTestCase {
    private let inspector = SiteInspector()
    private let fm = FileManager.default

    private func makeFolder(packageJSON: String?) throws -> URL {
        let folder = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("kd-node-\(UUID().uuidString)", isDirectory: true)
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

    func testClassifiesPackageJSONAsNode() throws {
        let folder = try makeFolder(packageJSON: #"{"scripts": {"dev": "vite"}}"#)
        defer { try? fm.removeItem(at: folder) }
        XCTAssertEqual(inspector.inspect(folder: folder).type, .node)
    }

    func testClassifiesPackageJSONWithoutScriptsAsNode() throws {
        let folder = try makeFolder(packageJSON: #"{"name": "app"}"#)
        defer { try? fm.removeItem(at: folder) }
        XCTAssertEqual(inspector.inspect(folder: folder).type, .node)
    }

    func testClassifiesBareFolderAsStatic() throws {
        let folder = try makeFolder(packageJSON: nil)
        defer { try? fm.removeItem(at: folder) }
        XCTAssertEqual(inspector.inspect(folder: folder).type, .staticSite)
    }
}
