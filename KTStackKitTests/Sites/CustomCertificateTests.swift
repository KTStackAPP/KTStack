import KTStackCore
import XCTest
@testable import KTStackKit

// Sinh cặp cert/key tự ký bằng openssl hệ thống, SAN tuỳ chọn.
enum TestCertificate {
    static func make(in dir: URL, names: [String] = ["app.test", "*.app.test"]) throws -> (cert: URL, key: URL) {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let cert = dir.appendingPathComponent("cert.pem"), key = dir.appendingPathComponent("key.pem")
        let san = names.map { "DNS:\($0)" }.joined(separator: ",")
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/openssl")
        proc.arguments = [
            "req", "-x509", "-newkey", "rsa:2048", "-nodes", "-keyout", key.path, "-out", cert.path,
            "-days", "30", "-subj", "/CN=\(names[0])", "-addext", "subjectAltName=\(san)",
        ]
        proc.standardOutput = FileHandle.nullDevice
        proc.standardError = FileHandle.nullDevice
        try proc.run()
        proc.waitUntilExit()
        guard proc.terminationStatus == 0 else { throw CocoaError(.fileWriteUnknown) }
        return (cert, key)
    }
}

final class CustomCertificateTests: XCTestCase {
    private let fm = FileManager.default
    private var root: URL!
    private var paths: AppSupportPaths!

    override func setUpWithError() throws {
        root = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("kt-customcert-\(UUID().uuidString)", isDirectory: true)
        paths = AppSupportPaths(root: root)
        try paths.ensureDirectoryTree()
    }

    override func tearDownWithError() throws {
        try? fm.removeItem(at: root)
    }

    private func site(secure: Bool = true, cert: SiteCustomCertificate? = nil, aliases: [String] = []) -> Site {
        Site(
            name: "app", path: "/tmp/app", docroot: "/tmp/app/public", domain: "app.test",
            phpVersion: "8.4", type: .php, secure: secure, backendPort: 4001, aliases: aliases,
            customCertificate: cert
        )
    }

    private let sampleCert = SiteCustomCertificate(
        sourceCertPath: "/tmp/fullchain.pem", sourceKeyPath: "/tmp/privkey.pem",
        notAfter: Date(timeIntervalSince1970: 2_000_000_000), names: ["app.test"]
    )

    private func pem(_ names: [String] = ["app.test", "*.app.test"]) throws -> (cert: Data, key: Data) {
        let files = try TestCertificate.make(in: root.appendingPathComponent("src-\(UUID().uuidString)"), names: names)
        return (try Data(contentsOf: files.cert), try Data(contentsOf: files.key))
    }

    func testOldSiteJSONDecodesWithoutCustomCertificate() throws {
        let json = #"{"name":"a","path":"/a","docroot":"/a","domain":"a.test","phpVersion":"8.4","type":"php"}"#
        let decoded = try JSONDecoder().decode(Site.self, from: Data(json.utf8))
        XCTAssertNil(decoded.customCertificate)
        XCTAssertFalse(decoded.usesCustomCertificate)
    }

    func testCustomCertificateRoundtrips() throws {
        let original = site(cert: sampleCert)
        let decoded = try JSONDecoder().decode(Site.self, from: JSONEncoder().encode(original))
        XCTAssertEqual(decoded.customCertificate, sampleCert)
    }

    func testInspectorReadsNamesAndExpiry() throws {
        let pair = try pem()
        let info = try CustomCertificateInspector().inspect(certPEM: pair.cert, keyPEM: pair.key)
        XCTAssertEqual(info.names, ["app.test", "*.app.test"])
        XCTAssertGreaterThan(info.notAfter, Date())
    }

    func testInspectorRefusesExpiredCertificate() throws {
        let pair = try pem()
        let notAfter = try CustomCertificateInspector().inspect(certPEM: pair.cert, keyPEM: pair.key).notAfter
        XCTAssertThrowsError(
            try CustomCertificateInspector().inspect(certPEM: pair.cert, keyPEM: pair.key, now: notAfter.addingTimeInterval(1))
        ) { XCTAssertEqual($0 as? CustomCertificateError, .expired(notAfter)) }
    }

    func testInspectorRefusesEncryptedKey() throws {
        let pair = try pem()
        let key = Data("-----BEGIN ENCRYPTED PRIVATE KEY-----\nabc\n-----END ENCRYPTED PRIVATE KEY-----\n".utf8)
        XCTAssertThrowsError(try CustomCertificateInspector().inspect(certPEM: pair.cert, keyPEM: key)) {
            XCTAssertEqual($0 as? CustomCertificateError, .encryptedKey)
        }
    }

    func testInspectorRefusesNonPEMCertificate() throws {
        let pair = try pem()
        XCTAssertThrowsError(try CustomCertificateInspector().inspect(certPEM: Data("nope".utf8), keyPEM: pair.key)) {
            XCTAssertEqual($0 as? CustomCertificateError, .notPEMCertificate)
        }
    }

    func testUncoveredMatchesWildcardOneLabelDeep() {
        let certNames = ["app.test", "*.app.test"]
        XCTAssertEqual(CustomCertificateInspector.uncovered(["a.app.test"], by: certNames), [])
        XCTAssertEqual(CustomCertificateInspector.uncovered(["app.test"], by: certNames), [])
        XCTAssertEqual(CustomCertificateInspector.uncovered(["x.y.app.test"], by: certNames), ["x.y.app.test"])
        XCTAssertEqual(CustomCertificateInspector.uncovered(["app.test"], by: ["*.app.test"]), ["app.test"])
        XCTAssertEqual(CustomCertificateInspector.uncovered(["*.app.test"], by: certNames), [])
        XCTAssertEqual(CustomCertificateInspector.uncovered(["*.app.test"], by: ["*.test"]), ["*.app.test"])
    }

    func testGeneratorServesImportedCertificate() throws {
        let custom = site(cert: sampleCert)
        let pair = try pem()
        let store = CustomCertificateStore(paths: paths)
        try store.swapIn(id: custom.id.uuidString, staged: store.stage(id: custom.id.uuidString, certPEM: pair.cert, keyPEM: pair.key))

        let generator = SiteConfigGenerator(paths: paths)
        let vhost = generator.frontVhostText(for: custom)
        XCTAssertTrue(vhost.contains("certs-custom/\(custom.id.uuidString)/fullchain.pem"), vhost)
        XCTAssertTrue(vhost.contains("certs-custom/\(custom.id.uuidString)/privkey.pem"), vhost)
        XCTAssertTrue(generator.frontBindsTLS(for: [custom]))
    }

    func testGeneratorFallsBackToHTTPWhenImportedFilesMissing() {
        XCTAssertFalse(SiteConfigGenerator(paths: paths).frontBindsTLS(for: [site(cert: sampleCert)]))
    }

    private final class Calls: @unchecked Sendable {
        var mint = 0
        var verify = 0
        var install = 0
    }

    private func provisioner(_ calls: Calls, verifyError: Error? = nil) -> SiteHTTPSProvisioner {
        SiteHTTPSProvisioner(
            caCert: URL(fileURLWithPath: "/dev/null"),
            tld: "test",
            trustQuery: { _ in false },
            installCA: { calls.install += 1 },
            mintLeaf: { _, _, _ in calls.mint += 1 },
            verifyCustom: { _ in
                calls.verify += 1
                if let verifyError { throw verifyError }
            }
        )
    }

    func testProvisionerNeverMintsOverImportedCertificate() throws {
        let calls = Calls()
        try provisioner(calls).enableHTTPS(for: site(cert: sampleCert))
        XCTAssertEqual(calls.mint, 0)
        XCTAssertEqual(calls.install, 0)
        XCTAssertEqual(calls.verify, 1)
    }

    func testProvisionerRefusesWhenImportedCertificateStopsCovering() {
        let calls = Calls()
        let error = CustomCertificateError.namesNotCovered(["b.test"])
        XCTAssertThrowsError(try provisioner(calls, verifyError: error).enableHTTPS(for: site(cert: sampleCert, aliases: ["b.test"]))) {
            XCTAssertEqual($0 as? CustomCertificateError, error)
        }
        XCTAssertEqual(calls.mint, 0)
    }

    func testProvisionerStillMintsLocalSites() throws {
        let calls = Calls()
        try provisioner(calls).enableHTTPS(for: site())
        XCTAssertEqual(calls.mint, 1)
        XCTAssertEqual(calls.verify, 0)
    }

    func testVerifyCoverageReadsStoredPair() throws {
        let store = CustomCertificateStore(paths: paths)
        let covered = site(cert: sampleCert, aliases: ["a.app.test"])
        let pair = try pem()
        try store.swapIn(id: covered.id.uuidString, staged: store.stage(id: covered.id.uuidString, certPEM: pair.cert, keyPEM: pair.key))
        XCTAssertNoThrow(try store.verifyCoverage(for: covered))

        var uncovered = covered
        uncovered.aliases = ["other.test"]
        XCTAssertThrowsError(try store.verifyCoverage(for: uncovered)) {
            XCTAssertEqual($0 as? CustomCertificateError, .namesNotCovered(["other.test"]))
        }
    }

    func testStageWritesKeyWithOwnerOnlyMode() throws {
        let staged = try CustomCertificateStore(paths: paths).stage(id: "x", certPEM: Data("c".utf8), keyPEM: Data("k".utf8))
        let keyMode = try fm.attributesOfItem(atPath: staged.appendingPathComponent("privkey.pem").path)[.posixPermissions] as? Int
        let dirMode = try fm.attributesOfItem(atPath: staged.path)[.posixPermissions] as? Int
        XCTAssertEqual(keyMode, 0o600)
        XCTAssertEqual(dirMode, 0o700)
    }

    func testRollbackRestoresPreviousPair() throws {
        let store = CustomCertificateStore(paths: paths)
        try store.swapIn(id: "x", staged: store.stage(id: "x", certPEM: Data("old-c".utf8), keyPEM: Data("old-k".utf8)))
        try store.swapIn(id: "x", staged: store.stage(id: "x", certPEM: Data("new-c".utf8), keyPEM: Data("new-k".utf8)))
        XCTAssertEqual(try Data(contentsOf: paths.siteCustomCert("x")), Data("new-c".utf8))

        store.rollback(id: "x")
        XCTAssertEqual(try Data(contentsOf: paths.siteCustomCert("x")), Data("old-c".utf8))
        XCTAssertEqual(try Data(contentsOf: paths.siteCustomKey("x")), Data("old-k".utf8))
    }

    func testCommitDropsBackup() throws {
        let store = CustomCertificateStore(paths: paths)
        try store.swapIn(id: "x", staged: store.stage(id: "x", certPEM: Data("a".utf8), keyPEM: Data("a".utf8)))
        try store.swapIn(id: "x", staged: store.stage(id: "x", certPEM: Data("b".utf8), keyPEM: Data("b".utf8)))
        store.commit(id: "x")
        XCTAssertFalse(fm.fileExists(atPath: paths.customCertsDir.appendingPathComponent("x.bak").path))
    }

    func testPruneRemovesUnknownIDsAndKeepsKnown() throws {
        let store = CustomCertificateStore(paths: paths)
        for id in ["keep", "gone"] {
            try store.swapIn(id: id, staged: store.stage(id: id, certPEM: Data("c".utf8), keyPEM: Data("k".utf8)))
        }
        _ = try store.stage(id: "gone", certPEM: Data("c".utf8), keyPEM: Data("k".utf8))
        try fm.createDirectory(at: paths.customCertsDir.appendingPathComponent("keep.bak"), withIntermediateDirectories: true)

        store.pruneOrphans(keeping: ["keep"])
        let left = Set(try fm.contentsOfDirectory(atPath: paths.customCertsDir.path))
        XCTAssertEqual(left, ["keep", "keep.bak"])
    }
}
