import KTStackCore
import XCTest
@testable import KTStackKit

final class PHPAutoPrependTests: XCTestCase {
    private var root: URL!
    private var paths: AppSupportPaths!
    private var store: PHPIniStore!
    private var prepend: PHPAutoPrepend!
    private let version = "8.4"
    private let file = "/tmp/ktstack/php-vardumper-prepend.php"

    override func setUpWithError() throws {
        root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("ktstack-prepend-\(UUID().uuidString)")
        paths = AppSupportPaths(root: root)
        store = PHPIniStore(paths: paths)
        prepend = PHPAutoPrepend(paths: paths)
        try store.ensureSeeded(version: version)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    func testSetPatchesIniWithAutoPrependFile() throws {
        try prepend.set(file: file, version: version)
        let ini = try store.read(version: version)
        XCTAssertTrue(ini.contains("auto_prepend_file"))
        XCTAssertTrue(ini.contains(file))
    }

    func testIsSetReturnsFalseBeforeSet() {
        XCTAssertFalse(prepend.isSet(file: file, version: version))
    }

    func testIsSetReturnsTrueAfterSet() throws {
        try prepend.set(file: file, version: version)
        XCTAssertTrue(prepend.isSet(file: file, version: version))
    }

    func testSetIsIdempotent() throws {
        try prepend.set(file: file, version: version)
        try prepend.set(file: file, version: version)
        let ini = try store.read(version: version)
        let occurrences = ini.components(separatedBy: file).count - 1
        XCTAssertEqual(occurrences, 1, "auto_prepend_file should appear exactly once after double-set")
    }

    func testRemoveClearsOurLine() throws {
        try prepend.set(file: file, version: version)
        try prepend.remove(file: file, version: version)
        let ini = try store.read(version: version)
        XCTAssertFalse(ini.contains(file))
    }

    func testIsSetReturnsFalseAfterRemove() throws {
        try prepend.set(file: file, version: version)
        try prepend.remove(file: file, version: version)
        XCTAssertFalse(prepend.isSet(file: file, version: version))
    }

    func testRemovePreservesUnrelatedAutoPrependFile() throws {
        var ini = try store.read(version: version)
        ini += "\nauto_prepend_file = /some/other/prepend.php\n"
        try store.write(version: version, contents: ini)
        try prepend.set(file: file, version: version)
        try prepend.remove(file: file, version: version)
        let result = try store.read(version: version)
        XCTAssertTrue(result.contains("/some/other/prepend.php"), "Unrelated auto_prepend_file must be preserved")
    }
}
