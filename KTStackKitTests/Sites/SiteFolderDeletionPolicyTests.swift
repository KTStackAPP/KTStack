import XCTest
@testable import KTStackKit

final class SiteFolderDeletionPolicyTests: XCTestCase {
    private let policy = SiteFolderDeletionPolicy(
        home: URL(fileURLWithPath: "/Users/dev", isDirectory: true),
        ktstackRoot: URL(fileURLWithPath: "/Users/dev/Library/Application Support/KTStack", isDirectory: true),
        sitesRoot: URL(fileURLWithPath: "/Users/dev/Sites/WWW", isDirectory: true)
    )

    private func blocked(_ path: String, others: [String] = []) -> Bool {
        policy.deletionBlocker(for: URL(fileURLWithPath: path, isDirectory: true), otherSitePaths: others) != nil
    }

    func testRejectsRootHomeAndHomeAncestors() {
        XCTAssertTrue(blocked("/"))
        XCTAssertTrue(blocked("/Users"))
        XCTAssertTrue(blocked("/Users/dev"))
        XCTAssertTrue(blocked("/Users/dev/"))
    }

    func testComparisonIsCaseInsensitive() {
        XCTAssertTrue(blocked("/users/DEV"))
        XCTAssertTrue(blocked("/Users/dev/documents"))
    }

    func testRejectsStandardUserFoldersButAllowsTheirChildren() {
        for name in ["Desktop", "Documents", "Downloads", "Library", "Pictures"] {
            XCTAssertTrue(blocked("/Users/dev/\(name)"), name)
        }
        XCTAssertFalse(blocked("/Users/dev/Documents/shop"))
    }

    func testRejectsSystemTreesAndVolumeRoots() {
        XCTAssertTrue(blocked("/Applications"))
        XCTAssertTrue(blocked("/Applications/Safari.app"))
        XCTAssertTrue(blocked("/System/Library"))
        XCTAssertTrue(blocked("/usr/local"))
        XCTAssertTrue(blocked("/Volumes/External"))
        XCTAssertFalse(blocked("/Volumes/External/sites/shop"))
    }

    func testRejectsKTStackRootItsParentsAndContents() {
        XCTAssertTrue(blocked("/Users/dev/Library/Application Support"))
        XCTAssertTrue(blocked("/Users/dev/Library/Application Support/KTStack"))
        XCTAssertTrue(blocked("/Users/dev/Library/Application Support/KTStack/data"))
    }

    func testRejectsSitesRootAndItsParentButAllowsSites() {
        XCTAssertTrue(blocked("/Users/dev/Sites"))
        XCTAssertTrue(blocked("/Users/dev/Sites/WWW"))
        XCTAssertFalse(blocked("/Users/dev/Sites/WWW/shop"))
    }

    func testRejectsAncestorOrTwinOfAnotherSite() {
        XCTAssertTrue(blocked("/Users/dev/code", others: ["/Users/dev/code/blog"]))
        XCTAssertTrue(blocked("/Users/dev/code/blog", others: ["/Users/dev/Code/Blog"]))
        XCTAssertFalse(blocked("/Users/dev/code/shop", others: ["/Users/dev/code/blog"]))
    }

    func testCanonicalStripsDataVolumeAndDotSegments() {
        XCTAssertEqual(SiteFolderDeletionPolicy.canonical("/System/Volumes/Data/Users/dev/x"), "/users/dev/x")
        XCTAssertEqual(SiteFolderDeletionPolicy.canonical("/Users/dev/a/../b/"), "/users/dev/b")
    }

    func testSymlinkToProtectedFolderIsRejected() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("kt-policy-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let link = dir.appendingPathComponent("innocent")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: FileManager.default.homeDirectoryForCurrentUser)
        XCTAssertTrue(SiteFolderDeletionPolicy.standard().isProtected(link))
    }
}
