import KTStackCore
import Security
import XCTest
@testable import KTStackKit

final class RestrictedRootCATests: XCTestCase {
    private var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("kt-ca-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)
    }

    func testConfigPermitsOnlyDevNamesAndLoopback() {
        let config = RestrictedRootCA.opensslConfig(tlds: ["test", "dev.local"], tag: "abcd")
        XCTAssertTrue(config.contains(
            "nameConstraints = critical, permitted;DNS:test, permitted;DNS:dev.local, permitted;IP:127.0.0.0/255.0.0.0, "
                + "permitted;IP:::1/ffff:ffff:ffff:ffff:ffff:ffff:ffff:ffff"
        ), config)
        XCTAssertTrue(config.contains("O = mkcert development CA"))
        XCTAssertTrue(config.contains("CA:TRUE, pathlen:0"))
    }

    @MainActor
    func testPermittedTLDsAddCustomTLDOnlyOnce() {
        XCTAssertEqual(RestrictedRootCA.permittedTLDs(including: "test"), AppPreferences.safeTLDs)
        XCTAssertEqual(RestrictedRootCA.permittedTLDs(including: "lan"), AppPreferences.safeTLDs + ["lan"])
    }

    func testPolicyDefaultsToOn() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "kt-ca-\(UUID().uuidString)"))
        XCTAssertTrue(RestrictedRootCA.isEnabled(defaults: defaults))
        defaults.set(false, forKey: RestrictedRootCA.policyKey)
        XCTAssertFalse(RestrictedRootCA.isEnabled(defaults: defaults))
    }

    func testCACreatedElsewhereCountsAsUnrestricted() throws {
        XCTAssertEqual(RestrictedRootCA.coverage(caDir: dir), .none)
        try Data("-----BEGIN CERTIFICATE-----\nAAAA\n-----END CERTIFICATE-----\n".utf8)
            .write(to: dir.appendingPathComponent("rootCA.pem"))
        XCTAssertEqual(RestrictedRootCA.coverage(caDir: dir), .unrestricted)
        XCTAssertTrue(RestrictedRootCA.Coverage.unrestricted.covers("anything"))
        XCTAssertFalse(RestrictedRootCA.Coverage.restricted(["test"]).covers("lan"))
    }

    func testGeneratedCAPassesHelperCheckAndOnlyValidatesDevNames() throws {
        try XCTSkipUnless(FileManager.default.isExecutableFile(atPath: "/usr/bin/openssl"))
        try RestrictedRootCA.generate(caDir: dir, tlds: ["test"])
        let caPEM = try Data(contentsOf: dir.appendingPathComponent("rootCA.pem"))
        XCTAssertNil(RootCAConstraint.validateKTStackRootCA(pemData: caPEM))
        XCTAssertEqual(RestrictedRootCA.coverage(caDir: dir), .restricted(["test"]))
        XCTAssertTrue(try evaluate(host: "shop.test", caPEM: caPEM))
        XCTAssertFalse(try evaluate(host: "example.com", caPEM: caPEM))
    }

    func testRegeneratingKeepsThePreviousCA() throws {
        try XCTSkipUnless(FileManager.default.isExecutableFile(atPath: "/usr/bin/openssl"))
        try RestrictedRootCA.generate(caDir: dir, tlds: ["test"])
        let first = try Data(contentsOf: dir.appendingPathComponent("rootCA.pem"))
        try RestrictedRootCA.generate(caDir: dir, tlds: ["test", "lan"])
        XCTAssertNotEqual(try Data(contentsOf: dir.appendingPathComponent("rootCA.pem")), first)
        XCTAssertEqual(RestrictedRootCA.coverage(caDir: dir), .restricted(["test", "lan"]))
        let retired = try FileManager.default.contentsOfDirectory(
            at: dir.appendingPathComponent("retired"), includingPropertiesForKeys: nil
        )
        XCTAssertEqual(retired.count, 1)
        XCTAssertEqual(try Data(contentsOf: retired[0].appendingPathComponent("rootCA.pem")), first)
        XCTAssertTrue(FileManager.default.fileExists(atPath: retired[0].appendingPathComponent("rootCA-key.pem").path))
    }

    private func evaluate(host: String, caPEM: Data) throws -> Bool {
        let key = dir.appendingPathComponent("\(host).key"), csr = dir.appendingPathComponent("\(host).csr")
        let leaf = dir.appendingPathComponent("\(host).pem"), ext = dir.appendingPathComponent("\(host).cnf")
        try "[e]\nsubjectAltName=DNS:\(host)\nextendedKeyUsage=serverAuth\nbasicConstraints=CA:FALSE\n"
            .write(to: ext, atomically: true, encoding: .utf8)
        try openssl(["req", "-new", "-newkey", "rsa:2048", "-nodes", "-keyout", key.path, "-subj", "/CN=\(host)", "-out", csr.path])
        try openssl([
            "x509", "-req", "-in", csr.path, "-CA", dir.appendingPathComponent("rootCA.pem").path,
            "-CAkey", dir.appendingPathComponent("rootCA-key.pem").path, "-set_serial", "7", "-days", "365",
            "-sha256", "-extfile", ext.path, "-extensions", "e", "-out", leaf.path,
        ])
        let leafCert = try XCTUnwrap(certificate(try Data(contentsOf: leaf)))
        let caCert = try XCTUnwrap(certificate(caPEM))
        var trust: SecTrust?
        XCTAssertEqual(SecTrustCreateWithCertificates(leafCert, SecPolicyCreateSSL(true, host as CFString), &trust), errSecSuccess)
        let evaluation = try XCTUnwrap(trust)
        SecTrustSetAnchorCertificates(evaluation, [caCert] as CFArray)
        SecTrustSetAnchorCertificatesOnly(evaluation, true)
        SecTrustSetNetworkFetchAllowed(evaluation, false)
        return SecTrustEvaluateWithError(evaluation, nil)
    }

    private func certificate(_ pem: Data) -> SecCertificate? {
        RootCAConstraint.pemToDER(pem).flatMap { SecCertificateCreateWithData(nil, $0 as CFData) }
    }

    private func openssl(_ args: [String]) throws {
        let res = try ProcessRunner().run("/usr/bin/openssl", args, timeout: 60)
        XCTAssertTrue(res.succeeded, res.stderrText)
    }
}
