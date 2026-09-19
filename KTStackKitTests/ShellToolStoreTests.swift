import KTStackCore
import XCTest
@testable import KTStackKit

final class ShellToolStoreTests: XCTestCase {
    private var tmp: URL!
    private let fm = FileManager.default

    override func setUpWithError() throws {
        tmp = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("ktstack-toolstore-tests-\(UUID().uuidString)")
        try fm.createDirectory(at: tmp, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? fm.removeItem(at: tmp)
    }

    func testStoreDefaultsToEnabledWhenFileMissing() {
        let store = ShellToolStore(configFile: tmp.appendingPathComponent("shell-tools.json"))
        XCTAssertTrue(store.isEnabled("mysql"))
        XCTAssertTrue(store.isEnabled("node"))
        XCTAssertTrue(store.allStates().isEmpty)
    }

    func testStorePersistsIndividualToolToggle() throws {
        let file = tmp.appendingPathComponent("shell-tools.json")
        let store = ShellToolStore(configFile: file)

        try store.setEnabled("node", enabled: false)
        XCTAssertFalse(store.isEnabled("node"))
        XCTAssertTrue(store.isEnabled("php"))

        let reloaded = ShellToolStore(configFile: file)
        XCTAssertFalse(reloaded.isEnabled("node"))
        XCTAssertTrue(reloaded.isEnabled("php"))
        XCTAssertEqual(reloaded.allStates()["node"], false)
    }

    func testStoreTogglesEntireSuite() throws {
        let file = tmp.appendingPathComponent("shell-tools.json")
        let store = ShellToolStore(configFile: file)

        try store.setSuiteEnabled(.mysql, enabled: false)
        XCTAssertFalse(store.isEnabled("mysql"))
        XCTAssertFalse(store.isEnabled("mysqldump"))
        XCTAssertFalse(store.isEnabled("mysqladmin"))
        XCTAssertTrue(store.isEnabled("php"))

        try store.setSuiteEnabled(.mysql, enabled: true)
        XCTAssertTrue(store.isEnabled("mysql"))
        XCTAssertTrue(store.isEnabled("mysqldump"))
        XCTAssertTrue(store.isEnabled("mysqladmin"))
    }
}
