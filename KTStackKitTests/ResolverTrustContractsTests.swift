import KTPlatformContracts
import KTStackCore
import XCTest
@testable import KTStackKit

@MainActor
final class ResolverTrustContractsTests: XCTestCase {
    func testDNSStateAfterInit() {
        let sut = DNSAutomationService(bundledDnsmasq: URL(fileURLWithPath: "/dev/null"), tld: "test")
        XCTAssertNotEqual(sut.dnsState.status, .unknown)
        XCTAssertEqual(sut.dnsState.usesHelper, sut.usesHelper)
    }

    func testDNSStreamFirstElement() async {
        let sut = DNSAutomationService(bundledDnsmasq: URL(fileURLWithPath: "/dev/null"), tld: "test")
        var iterator = (sut as any DNSResolverManaging).dnsStates().makeAsyncIterator()
        let first = await iterator.next()
        XCTAssertEqual(first, sut.dnsState)
    }

    func testCATrustStateWithoutCA() throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("kd-catrust-\(UUID().uuidString)", isDirectory: true)
        let paths = AppSupportPaths(root: root)
        try paths.ensureDirectoryTree()
        defer { try? FileManager.default.removeItem(at: root) }
        let sut = CATrustService(paths: paths, mkcertBinary: URL(fileURLWithPath: "/dev/null"))
        XCTAssertEqual(sut.caTrustState, CATrustState(exists: false, trusted: false))
    }

    func testCATrustStreamFirstElement() async throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("kd-catrust-\(UUID().uuidString)", isDirectory: true)
        let paths = AppSupportPaths(root: root)
        try paths.ensureDirectoryTree()
        defer { try? FileManager.default.removeItem(at: root) }
        let sut = CATrustService(paths: paths, mkcertBinary: URL(fileURLWithPath: "/dev/null"))
        var iterator = (sut as any CATrustProviding).caTrustStates().makeAsyncIterator()
        let first = await iterator.next()
        XCTAssertEqual(first, sut.caTrustState)
    }
}
