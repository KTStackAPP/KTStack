import KTStackCore
import XCTest
@testable import KTStackKit

final class SiteWorkerCommandTests: XCTestCase {
    func testSplitsOnWhitespace() {
        XCTAssertEqual(
            SiteWorkerCommand.arguments("php artisan  queue:work\t--tries=3"),
            ["php", "artisan", "queue:work", "--tries=3"]
        )
    }

    func testQuotesAndEscapesGroupWords() {
        XCTAssertEqual(
            SiteWorkerCommand.arguments(#"php artisan queue:work --queue='high, low' --name="a \"b\"" c\ d"#),
            ["php", "artisan", "queue:work", "--queue=high, low", #"--name=a "b""#, "c d"]
        )
        XCTAssertEqual(SiteWorkerCommand.arguments("echo ''"), ["echo", ""])
    }

    func testRejectsUnbalancedQuotesAndEmptyCommands() {
        XCTAssertNil(SiteWorkerCommand.arguments("php 'artisan"))
        XCTAssertNil(SiteWorkerCommand.arguments("php \"artisan"))
        XCTAssertNil(SiteWorkerCommand.arguments("php artisan\\"))
        XCTAssertNil(SiteWorkerCommand.arguments("   "))
    }

    func testRejectsControlCharactersAndOversizedCommands() {
        XCTAssertNil(SiteWorkerCommand.arguments("php artisan\nrm -rf /"))
        XCTAssertNil(SiteWorkerCommand.arguments("php \u{0}"))
        XCTAssertNil(SiteWorkerCommand.arguments(String(repeating: "a", count: SiteWorkerCommand.maxLength + 1)))
    }

    func testRenderRoundTripsThroughArguments() {
        let words = ["php", "artisan", "queue:work", "--queue=high, low", "it's"]
        XCTAssertEqual(SiteWorkerCommand.arguments(SiteWorkerCommand.render(words)), words)
    }
}

final class SiteWorkersValidationTests: XCTestCase {
    func testPresetsAreValid() {
        XCTAssertNil(SiteWorkers.validate(SiteWorkerPreset.allCases.map { $0.makeWorker() }))
        XCTAssertFalse(SiteWorkerPreset.laravelQueue.makeWorker().enabled)
    }

    func testNameRules() {
        XCTAssertTrue(SiteWorkers.isValidName("queue"))
        XCTAssertTrue(SiteWorkers.isValidName("queue-2"))
        XCTAssertFalse(SiteWorkers.isValidName(""))
        XCTAssertFalse(SiteWorkers.isValidName("-queue"))
        XCTAssertFalse(SiteWorkers.isValidName("Queue"))
        XCTAssertFalse(SiteWorkers.isValidName("queue/../x"))
        XCTAssertFalse(SiteWorkers.isValidName(String(repeating: "a", count: SiteWorkers.maxNameLength + 1)))
    }

    func testRejectsDuplicateNamesBadCommandsAndTooMany() {
        let queue = SiteWorker(name: "queue", command: "php artisan queue:work")
        XCTAssertEqual(SiteWorkers.validate([queue, queue]), .duplicateName("queue"))
        XCTAssertEqual(SiteWorkers.validate([SiteWorker(name: "x", command: "php 'a")]), .invalidCommand("x"))
        XCTAssertEqual(SiteWorkers.validate([SiteWorker(name: "X", command: "php")]), .invalidName("X"))
        let many = (0...SiteWorkers.maxPerSite).map { SiteWorker(name: "w\($0)", command: "php") }
        XCTAssertEqual(SiteWorkers.validate(many), .tooMany(SiteWorkers.maxPerSite))
    }

    func testSuggestedNameAvoidsTakenNames() {
        let existing = [SiteWorker(name: "queue", command: "php"), SiteWorker(name: "queue-2", command: "php")]
        XCTAssertEqual(SiteWorkers.suggestedName("queue", existing: existing), "queue-3")
        XCTAssertEqual(SiteWorkers.suggestedName("scheduler", existing: existing), "scheduler")
    }
}

@MainActor
final class SiteWorkersRegistryTests: XCTestCase {
    private let fm = FileManager.default
    private var root: URL!

    override func setUpWithError() throws {
        root = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("kd-workers-\(UUID().uuidString)")
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? fm.removeItem(at: root)
    }

    private var store: URL { root.appendingPathComponent("sites.json") }

    func testOldSitesJSONDecodesWithoutWorkers() throws {
        let json = """
        {"name":"shop","path":"/s","docroot":"/s","domain":"shop.test","phpVersion":"8.4","type":"php"}
        """
        let decoded = try JSONDecoder().decode(Site.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.workers, [])
    }

    func testMalformedWorkerIsDroppedWithoutLosingTheSite() throws {
        let json = """
        {"name":"shop","path":"/s","docroot":"/s","domain":"shop.test","phpVersion":"8.4","type":"php",
         "workers":[{"name":"queue","command":"php artisan queue:work"},{"name":"broken"}]}
        """
        let decoded = try JSONDecoder().decode(Site.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.workers.map(\.name), ["queue"])
    }

    func testWorkerWithoutEnabledFlagDecodesDisabled() throws {
        let json = #"{"name":"queue","command":"php artisan queue:work"}"#
        XCTAssertFalse(try JSONDecoder().decode(SiteWorker.self, from: Data(json.utf8)).enabled)
    }

    func testSupportsWorkersOnlyForPHPSitesWithAFolder() {
        let php = Site(name: "a", path: "/a", docroot: "/a", domain: "a.test", phpVersion: "8.4", type: .php)
        let proxy = Site(name: "b", path: "", docroot: "", domain: "b.test", phpVersion: "8.4", type: .proxy)
        let node = Site(name: "c", path: "/c", docroot: "/c", domain: "c.test", phpVersion: "8.4", type: .node)
        XCTAssertTrue(php.supportsWorkers)
        XCTAssertFalse(proxy.supportsWorkers)
        XCTAssertFalse(node.supportsWorkers)
    }

    func testSetWorkersPersistsAndRejectsInvalidLists() throws {
        let folder = root.appendingPathComponent("app", isDirectory: true)
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)
        let registry = SiteRegistry(storeURL: store, tld: "test")
        let site = try registry.add(folder: folder)
        let queue = SiteWorkerPreset.laravelQueue.makeWorker()

        try registry.setWorkers(site, [queue])
        XCTAssertThrowsError(try registry.setWorkers(site, [queue, queue]))
        registry.setWorkerEnabled(siteID: site.id, workerID: queue.id, true)

        let reloaded = SiteRegistry(storeURL: store, tld: "test")
        XCTAssertEqual(reloaded.sites.first?.workers.map(\.name), ["queue"])
        XCTAssertEqual(reloaded.sites.first?.workers.first?.enabled, true)
    }
}
