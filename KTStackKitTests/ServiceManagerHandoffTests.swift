import KTStackCore
import XCTest
@testable import KTStackKit

private actor HandoffCallLog {
    enum Event: Equatable { case start(ServiceKind), stop(ServiceKind), restart(ServiceKind) }
    private(set) var events: [Event] = []
    func record(_ event: Event) { events.append(event) }
}

private final class FakeService: ManagedService {
    let kind: ServiceKind
    let isInstalled: Bool
    let logsURL: URL? = nil
    private let log: HandoffCallLog
    var detail: String { ":\(kind.defaultPort ?? 0)" }

    init(_ kind: ServiceKind, installed: Bool = true, log: HandoffCallLog) {
        self.kind = kind
        isInstalled = installed
        self.log = log
    }

    func start() async throws { await log.record(.start(kind)) }
    func stop() async throws { await log.record(.stop(kind)) }
    func restart() async throws { await log.record(.restart(kind)) }
    func probe() async -> ServiceStatus { .stopped }
}

@MainActor
final class ServiceManagerHandoffTests: XCTestCase {
    private func makeManager() throws -> (ServiceManager, AppSupportPaths) {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("kd-handoff-\(UUID().uuidString)", isDirectory: true)
        let paths = AppSupportPaths(root: root)
        try paths.ensureDirectoryTree()
        let dns = DNSAutomationService(bundledDnsmasq: URL(fileURLWithPath: "/dev/null"), tld: "test")
        let server = LocalServerController(bundleBinDir: URL(fileURLWithPath: "/dev/null"), paths: paths)
        return (ServiceManager(server: server, dns: dns, paths: paths), paths)
    }

    private func setStatus(_ sut: ServiceManager, _ kind: ServiceKind, _ status: ServiceStatus) {
        if let index = sut.snapshots.firstIndex(where: { $0.kind == kind }) {
            sut.snapshots[index].status = status
        }
    }

    private func drainBusy(_ sut: ServiceManager) async {
        for _ in 0..<400 {
            if sut.busy.isEmpty { return }
            try? await Task.sleep(nanoseconds: 5_000_000)
        }
    }

    func testToggleStartsPreferredEngineOnlyAfterBootingOutSibling() async throws {
        let (sut, paths) = try makeManager()
        defer { try? FileManager.default.removeItem(at: paths.config.deletingLastPathComponent()) }
        let log = HandoffCallLog()
        sut.services[.mysql] = FakeService(.mysql, log: log)
        sut.services[.mariadb] = FakeService(.mariadb, log: log)
        setStatus(sut, .mariadb, .running)
        setStatus(sut, .mysql, .stopped)

        sut.toggle(ServiceKind.mysql)
        await drainBusy(sut)

        let events = await log.events
        XCTAssertEqual(events, [.stop(.mariadb), .start(.mysql)])
    }

    func testRestartWhileSiblingRunsStopsSiblingFirst() async throws {
        let (sut, paths) = try makeManager()
        defer { try? FileManager.default.removeItem(at: paths.config.deletingLastPathComponent()) }
        let log = HandoffCallLog()
        sut.services[.mysql] = FakeService(.mysql, log: log)
        sut.services[.mariadb] = FakeService(.mariadb, log: log)
        setStatus(sut, .mysql, .running)
        setStatus(sut, .mariadb, .stopped)

        sut.restart(ServiceKind.mariadb)
        await drainBusy(sut)

        let events = await log.events
        // Sibling (mysql) bootout trước, rồi mariadb start: không lúc nào hai job 3306 cùng loaded.
        XCTAssertEqual(events, [.stop(.mysql), .start(.mariadb)])
    }

    func testStartAllSkipsMariaDBAndBootsItOutForMySQL() async throws {
        let (sut, paths) = try makeManager()
        defer { try? FileManager.default.removeItem(at: paths.config.deletingLastPathComponent()) }
        let log = HandoffCallLog()
        sut.services[.mysql] = FakeService(.mysql, log: log)
        sut.services[.mariadb] = FakeService(.mariadb, log: log)
        setStatus(sut, .mariadb, .running)
        setStatus(sut, .mysql, .stopped)

        sut.startAll()
        await drainBusy(sut)

        let events = await log.events
        // MariaDB không bao giờ được start (MySQL thắng), và bị bootout trước khi MySQL start.
        XCTAssertFalse(events.contains(.start(.mariadb)))
        XCTAssertEqual(events, [.stop(.mariadb), .start(.mysql)])
    }

    func testToggleStartWithoutRunningSiblingDoesNotBootOut() async throws {
        let (sut, paths) = try makeManager()
        defer { try? FileManager.default.removeItem(at: paths.config.deletingLastPathComponent()) }
        let log = HandoffCallLog()
        sut.services[.mysql] = FakeService(.mysql, log: log)
        sut.services[.mariadb] = FakeService(.mariadb, log: log)
        setStatus(sut, .mariadb, .stopped)
        setStatus(sut, .mysql, .stopped)

        sut.toggle(ServiceKind.mysql)
        await drainBusy(sut)

        let events = await log.events
        XCTAssertEqual(events, [.start(.mysql)])
    }
}
