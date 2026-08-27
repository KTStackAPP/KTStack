import KTPlatformContracts
import KTStackCore
import XCTest
@testable import KTStackKit

@MainActor
final class ServiceManagingConformanceTests: XCTestCase {
    private func makeManager() throws -> (ServiceManager, AppSupportPaths) {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("kd-svcmgr-\(UUID().uuidString)", isDirectory: true)
        let paths = AppSupportPaths(root: root)
        try paths.ensureDirectoryTree()
        let dns = DNSAutomationService(bundledDnsmasq: URL(fileURLWithPath: "/dev/null"), tld: "test")
        let server = LocalServerController(bundleBinDir: URL(fileURLWithPath: "/dev/null"), paths: paths)
        return (ServiceManager(server: server, dns: dns, paths: paths), paths)
    }

    func testServiceStatesFollowManagerOrder() throws {
        let (sut, paths) = try makeManager()
        defer { try? FileManager.default.removeItem(at: paths.config.deletingLastPathComponent()) }
        let states = (sut as any ServiceManaging).serviceStates
        XCTAssertEqual(states.map(\.id), [.nginx, .phpFpm, .dnsmasq, .mysql, .mariadb, .postgres, .redis, .memcached, .mongodb, .mailpit])
        XCTAssertEqual(states.map(\.id.rawValue), ServiceManager.order.map(\.rawValue))
    }

    func testServiceIDRawValuesMatchServiceKind() {
        XCTAssertEqual(ServiceID.allCases.map(\.rawValue), ServiceKind.allCases.map(\.rawValue))
    }

    func testNginxDisplayNameIsWebServer() throws {
        let (sut, paths) = try makeManager()
        defer { try? FileManager.default.removeItem(at: paths.config.deletingLastPathComponent()) }
        let nginx = try XCTUnwrap(sut.serviceStates.first { $0.id == .nginx })
        XCTAssertEqual(nginx.displayName, "Web Server")
    }

    func testServiceIDEngineMapping() {
        XCTAssertEqual(ServiceID.mysql.engine, .mysql)
        XCTAssertEqual(ServiceID.mariadb.engine, .mariadb)
        XCTAssertEqual(ServiceID.postgres.engine, .postgres)
        XCTAssertEqual(ServiceID.redis.engine, .redis)
        XCTAssertEqual(ServiceID.memcached.engine, .memcached)
        XCTAssertEqual(ServiceID.mongodb.engine, .mongodb)
        for id in [ServiceID.nginx, .phpFpm, .dnsmasq, .mailpit] {
            XCTAssertNil(id.engine)
        }
    }

    func testStreamFirstElementEqualsCurrentStates() async throws {
        let (sut, paths) = try makeManager()
        defer { try? FileManager.default.removeItem(at: paths.config.deletingLastPathComponent()) }
        var iterator = (sut as any ServiceManaging).serviceStateStream().makeAsyncIterator()
        let first = await iterator.next()
        XCTAssertEqual(first, sut.serviceStates)
    }

    func testServiceHealthMapping() {
        XCTAssertEqual(ServiceHealth(.warning), .warning)
        XCTAssertEqual(ServiceHealth(.running), .running)
        XCTAssertEqual(ServiceHealth(.error), .error)
    }
}
