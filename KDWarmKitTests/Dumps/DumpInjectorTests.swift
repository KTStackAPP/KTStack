import XCTest
@testable import KDWarmKit

final class DumpInjectorTests: XCTestCase {
    private var root: URL!
    private var paths: AppSupportPaths!
    private var injector: DumpInjector!
    private var store: PHPIniStore!
    private let version = "8.4"

    override func setUpWithError() throws {
        root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("kdwarm-injector-\(UUID().uuidString)")
        paths = AppSupportPaths(root: root)
        injector = DumpInjector(paths: paths)
        store = PHPIniStore(paths: paths)
        try store.ensureSeeded(version: version)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    func testEnableWritesPrependFile() throws {
        try injector.enable(version: version, port: 9912)
        XCTAssertTrue(FileManager.default.fileExists(atPath: paths.dumpsPrependFile.path))
    }

    func testEnableSubstitutesPortInPrependFile() throws {
        try injector.enable(version: version, port: 9912)
        let content = try String(contentsOf: paths.dumpsPrependFile, encoding: .utf8)
        XCTAssertTrue(content.contains("9912"))
        XCTAssertFalse(content.contains("KDWARM_PORT"))
    }

    func testEnablePatchesIniWithAutoPrependFile() throws {
        try injector.enable(version: version, port: 9912)
        let ini = try store.read(version: version)
        XCTAssertTrue(ini.contains("auto_prepend_file"))
        XCTAssertTrue(ini.contains(paths.dumpsPrependFile.path))
    }

    func testIsEnabledReturnsTrueAfterEnable() throws {
        try injector.enable(version: version, port: 9912)
        XCTAssertTrue(injector.isEnabled(version: version))
    }

    func testIsEnabledReturnsFalseBeforeEnable() {
        XCTAssertFalse(injector.isEnabled(version: version))
    }

    func testDisableRemovesOurAutoPrependLine() throws {
        try injector.enable(version: version, port: 9912)
        try injector.disable(version: version)
        let ini = try store.read(version: version)
        XCTAssertFalse(ini.contains(paths.dumpsPrependFile.path))
    }

    func testDisableDoesNotRemoveUnrelatedAutoPrependFile() throws {
        var ini = try store.read(version: version)
        ini += "\nauto_prepend_file = /some/other/prepend.php\n"
        try store.write(version: version, contents: ini)
        try injector.enable(version: version, port: 9912)
        try injector.disable(version: version)
        let result = try store.read(version: version)
        XCTAssertTrue(result.contains("/some/other/prepend.php"), "Unrelated auto_prepend_file must be preserved")
    }

    func testIsEnabledReturnsFalseAfterDisable() throws {
        try injector.enable(version: version, port: 9912)
        try injector.disable(version: version)
        XCTAssertFalse(injector.isEnabled(version: version))
    }

    func testEnableIsIdempotentAndDoesNotDuplicateIniKey() throws {
        try injector.enable(version: version, port: 9912)
        try injector.enable(version: version, port: 9912)
        let ini = try store.read(version: version)
        let occurrences = ini.components(separatedBy: paths.dumpsPrependFile.path).count - 1
        XCTAssertEqual(occurrences, 1, "auto_prepend_file should appear exactly once after double-enable")
    }

    func testCleanupRemovesPrependFile() throws {
        try injector.enable(version: version, port: 9912)
        injector.cleanupPrependFile()
        XCTAssertFalse(FileManager.default.fileExists(atPath: paths.dumpsPrependFile.path))
    }

    func testCleanupIsNoOpWhenFileAbsent() {
        XCTAssertNoThrow(injector.cleanupPrependFile())
    }
}
