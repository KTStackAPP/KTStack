import KTStackCore
import XCTest
@testable import KTStackKit

@MainActor
final class SiteFolderSafetyTests: XCTestCase {
    private let fm = FileManager.default

    private func makeRegistry() -> (SiteRegistry, URL) {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("kd-reg-\(UUID().uuidString)", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return (SiteRegistry(storeURL: dir.appendingPathComponent("sites.json")), dir)
    }

    private func phpFolder(in dir: URL, named: String) throws -> URL {
        let f = dir.appendingPathComponent(named, isDirectory: true)
        let pub = f.appendingPathComponent("public", isDirectory: true)
        try fm.createDirectory(at: pub, withIntermediateDirectories: true)
        try "<?php".write(to: pub.appendingPathComponent("index.php"), atomically: true, encoding: .utf8)
        return f
    }

    func testFolderRemovalTargetRejectsAncestorOfAnotherSite() throws {
        let (reg, dir) = makeRegistry(); defer { try? fm.removeItem(at: dir) }
        let parent = try phpFolder(in: dir, named: "parent")
        let child = try phpFolder(in: parent, named: "child")
        let parentSite = try reg.add(folder: parent)
        _ = try reg.add(folder: child)

        XCTAssertThrowsError(try reg.folderRemovalTarget(parentSite)) { error in
            guard case .unsafeDeletePath = error as? SiteRegistry.RegistryError else {
                return XCTFail("unexpected error \(error)")
            }
        }
        XCTAssertTrue(fm.fileExists(atPath: child.path))
    }

    func testAddRejectsHomeFolder() {
        let (reg, dir) = makeRegistry(); defer { try? fm.removeItem(at: dir) }
        XCTAssertThrowsError(try reg.add(folder: fm.homeDirectoryForCurrentUser)) { error in
            XCTAssertEqual(error as? SiteRegistry.RegistryError, .unsafeSiteFolder(fm.homeDirectoryForCurrentUser.path))
        }
        XCTAssertTrue(reg.sites.isEmpty)
    }
}
