import KTStackCore
import XCTest
@testable import KTStackKit

@MainActor
final class SiteDomainAndTLSTests: XCTestCase {
    private let fm = FileManager.default
    private var root: URL!

    override func setUpWithError() throws {
        root = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("kd-domain-\(UUID().uuidString)")
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? fm.removeItem(at: root)
    }

    private func registry() -> SiteRegistry {
        SiteRegistry(storeURL: root.appendingPathComponent("sites.json"), tld: "test")
    }

    func testSlugTransliteratesToASCII() {
        XCTAssertEqual(DomainSlug.make("Café Đà Nẵng"), "cafe-da-nang")
        let slug = DomainSlug.make("日本 App")
        XCTAssertTrue(slug.allSatisfy { $0.isASCII }, slug)
        XCTAssertTrue(slug.hasSuffix("app"))
    }

    func testFolderWithAccentsGetsAnASCIIDomain() throws {
        let folder = root.appendingPathComponent("Tiệm Cà Phê", isDirectory: true)
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)
        let site = try registry().add(folder: folder)
        XCTAssertEqual(site.domain, "tiem-ca-phe.test")
    }

    func testProxyTargetCannotBeTheLocalFront() {
        let reg = registry()
        XCTAssertThrowsError(try reg.addProxy(name: "a", domain: "a.test", target: .loopback(port: 80)))
        XCTAssertThrowsError(try reg.addProxy(name: "b", domain: "b.test", target: ProxyTarget(scheme: .https, host: "localhost", port: 443)))
        XCTAssertNoThrow(try reg.addProxy(name: "c", domain: "c.test", target: .loopback(port: 8000)))
    }

    func testProxyTargetCannotBeAnotherRegisteredSite() throws {
        let reg = registry()
        _ = try reg.addProxy(name: "api", domain: "api.test", target: .loopback(port: 8000))
        XCTAssertThrowsError(try reg.addProxy(name: "web", domain: "web.test", target: ProxyTarget(scheme: .http, host: "api.test", port: 8080)))
    }

    func testMissingCertificateNeedsRenewal() throws {
        let paths = AppSupportPaths(root: root.appendingPathComponent("support"))
        let minter = CertMinter(paths: paths, runner: MkcertRunner(mkcert: paths.mkcertBinary, caroot: paths.caDir))
        XCTAssertTrue(CertRenewalPolicy(paths: paths, minter: minter).needsRenewal("shop.test"))
    }
}
