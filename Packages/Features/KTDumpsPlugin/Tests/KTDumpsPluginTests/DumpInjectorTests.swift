import KTPlatformContracts
import KTStackCore
import XCTest
@testable import KTDumpsPlugin

private final class StubPHP: PHPRuntimeConfiguring, @unchecked Sendable {
    var versions = ["8.4"]
    private(set) var setCalls: [(file: String, version: String)] = []
    private(set) var removeCalls: [(file: String, version: String)] = []
    private(set) var reloads: [String] = []
    var failSetForVersion: String?
    private var active: Set<String> = []

    var installedPHPVersions: [String] { versions }

    func setAutoPrepend(file: String, version: String) throws {
        if version == failSetForVersion { throw CocoaError(.fileWriteNoPermission) }
        setCalls.append((file, version))
        active.insert(file)
    }

    func removeAutoPrepend(file: String, version: String) throws {
        removeCalls.append((file, version))
        active.remove(file)
    }

    func isAutoPrependSet(file: String, version: String) -> Bool { active.contains(file) }

    @MainActor func reloadPHPPool(version: String) async throws { reloads.append(version) }
}

final class DumpInjectorTests: XCTestCase {
    private var root: URL!
    private var paths: AppSupportPaths!
    private var php: StubPHP!
    private var injector: DumpInjector!
    private let version = "8.4"

    override func setUpWithError() throws {
        root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("ktstack-injector-\(UUID().uuidString)")
        paths = AppSupportPaths(root: root)
        php = StubPHP()
        injector = DumpInjector(paths: paths, php: php)
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
        XCTAssertFalse(content.contains("KTSTACK_PORT"))
    }

    func testEnableSetsAutoPrependWithPrependPath() throws {
        try injector.enable(version: version, port: 9912)
        XCTAssertEqual(php.setCalls.count, 1)
        XCTAssertEqual(php.setCalls.first?.file, paths.dumpsPrependFile.path)
        XCTAssertEqual(php.setCalls.first?.version, version)
    }

    func testDisableRemovesAutoPrepend() throws {
        try injector.enable(version: version, port: 9912)
        try injector.disable(version: version)
        XCTAssertEqual(php.removeCalls.count, 1)
        XCTAssertEqual(php.removeCalls.first?.file, paths.dumpsPrependFile.path)
    }

    func testIsEnabledReflectsContractState() throws {
        XCTAssertFalse(injector.isEnabled(version: version))
        try injector.enable(version: version, port: 9912)
        XCTAssertTrue(injector.isEnabled(version: version))
        try injector.disable(version: version)
        XCTAssertFalse(injector.isEnabled(version: version))
    }

    func testCleanupRemovesPrependFile() throws {
        try injector.enable(version: version, port: 9912)
        injector.cleanupPrependFile()
        XCTAssertFalse(FileManager.default.fileExists(atPath: paths.dumpsPrependFile.path))
    }

    func testCleanupIsNoOpWhenFileAbsent() {
        XCTAssertNoThrow(injector.cleanupPrependFile())
    }

    func testLeftoverPrependIsRemovedOnStart() async throws {
        try injector.enable(version: version, port: 9912)
        await DumpInjector.reconcileLeftover(injector: injector, php: php)
        XCTAssertFalse(injector.isEnabled(version: version))
        XCTAssertFalse(FileManager.default.fileExists(atPath: paths.dumpsPrependFile.path))
    }

    func testTemplateTruncatesHugeStringsAndSurvivesInvalidUTF8() throws {
        try injector.enable(version: version, port: 9912)
        let content = try String(contentsOf: paths.dumpsPrependFile, encoding: .utf8)
        XCTAssertTrue(content.contains("65536"))
        XCTAssertTrue(content.contains("'truncated' => true"))
        XCTAssertTrue(content.contains("JSON_INVALID_UTF8_SUBSTITUTE"))
    }

    @MainActor
    func testPartialEnableIsRolledBack() async throws {
        php.versions = ["8.3", "8.4"]
        php.failSetForVersion = "8.4"
        let model = DumpsViewModel(php: php, server: DumpServer(), injector: injector)
        model.toggle(true)
        for _ in 0..<300 where model.busy { try await Task.sleep(nanoseconds: 10_000_000) }
        XCTAssertFalse(model.enabled)
        XCTAssertNotNil(model.errorMessage)
        XCTAssertEqual(php.removeCalls.map(\.version), ["8.3"])
        XCTAssertFalse(injector.isEnabled(version: "8.3"))
        XCTAssertFalse(FileManager.default.fileExists(atPath: paths.dumpsPrependFile.path))
    }
}
