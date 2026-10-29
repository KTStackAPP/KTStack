import KTStackCore
import XCTest
@testable import KTStackKit

@MainActor
final class SiteCertificateImporterTests: XCTestCase {
    private struct ReloadFailed: Error {}

    private final class Recorder {
        var persisted: [(SiteCustomCertificate?, Bool)] = []
        var generated = 0
        var reloads = 0
    }

    private let fm = FileManager.default
    private var root: URL!
    private var paths: AppSupportPaths!
    private var source: (cert: URL, key: URL)!

    override func setUp() async throws {
        root = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("kt-certimport-\(UUID().uuidString)", isDirectory: true)
        paths = AppSupportPaths(root: root)
        try paths.ensureDirectoryTree()
        source = try TestCertificate.make(in: root.appendingPathComponent("src"))
    }

    override func tearDown() async throws {
        try? fm.removeItem(at: root)
    }

    private func site(aliases: [String] = []) -> Site {
        Site(
            name: "app", path: "/tmp/app", docroot: "/tmp/app/public", domain: "app.test",
            phpVersion: "8.4", type: .php, backendPort: 4001, aliases: aliases
        )
    }

    private func importer(
        _ site: Site,
        _ recorder: Recorder,
        validate: NginxValidationResult = .valid,
        generateError: Error? = nil,
        reloadError: Error? = nil
    ) -> SiteCertificateImporter {
        SiteCertificateImporter(
            store: CustomCertificateStore(paths: paths),
            generate: { _ in
                recorder.generated += 1
                if let generateError { throw generateError }
            },
            validate: { validate },
            reload: {
                recorder.reloads += 1
                if let reloadError { throw reloadError }
            },
            liveSites: { [site] },
            persist: { _, cert, secure in recorder.persisted.append((cert, secure)) }
        )
    }

    private func seedPreviousPair(for site: Site) throws {
        let store = CustomCertificateStore(paths: paths)
        let id = site.id.uuidString
        try store.swapIn(id: id, staged: store.stage(id: id, certPEM: Data("old-c".utf8), keyPEM: Data("old-k".utf8)))
    }

    private func liveCert(_ site: Site) throws -> Data {
        try Data(contentsOf: paths.siteCustomCert(site.id.uuidString))
    }

    private var backupExists: Bool {
        (try? fm.contentsOfDirectory(atPath: paths.customCertsDir.path))?.contains { $0.hasSuffix(".bak") } ?? false
    }

    func testValidImportPersistsSecureAndCommits() async throws {
        let s = site(aliases: ["a.app.test"])
        try seedPreviousPair(for: s)
        let recorder = Recorder()
        try await importer(s, recorder).importCertificate(s, certPath: source.cert.path, keyPath: source.key.path)

        XCTAssertEqual(recorder.persisted.count, 1)
        XCTAssertEqual(recorder.persisted.first?.1, true)
        XCTAssertEqual(recorder.persisted.first?.0?.names, ["app.test", "*.app.test"])
        XCTAssertEqual(recorder.persisted.first?.0?.sourceCertPath, source.cert.path)
        XCTAssertEqual(try liveCert(s), try Data(contentsOf: source.cert))
        XCTAssertFalse(backupExists)
    }

    func testRejectedImportRestoresFilesWithoutPersisting() async throws {
        let s = site()
        try seedPreviousPair(for: s)
        let recorder = Recorder()
        do {
            try await importer(s, recorder, validate: .invalid("x")).importCertificate(s, certPath: source.cert.path, keyPath: source.key.path)
            XCTFail("expected rejection")
        } catch {
            XCTAssertEqual(error as? CustomCertificateError, .rejected("x"))
        }
        XCTAssertTrue(recorder.persisted.isEmpty)
        XCTAssertEqual(try liveCert(s), Data("old-c".utf8))
        XCTAssertEqual(recorder.generated, 2)
    }

    func testUnvalidatedImportIsReverted() async throws {
        let s = site()
        try seedPreviousPair(for: s)
        let recorder = Recorder()
        do {
            try await importer(s, recorder, validate: .couldNotRun).importCertificate(s, certPath: source.cert.path, keyPath: source.key.path)
            XCTFail("expected couldNotValidate")
        } catch {
            XCTAssertEqual(error as? CustomCertificateError, .couldNotValidate)
        }
        XCTAssertTrue(recorder.persisted.isEmpty)
        XCTAssertEqual(try liveCert(s), Data("old-c".utf8))
    }

    func testFailedRenderRestoresFiles() async throws {
        let s = site()
        try seedPreviousPair(for: s)
        let recorder = Recorder()
        do {
            try await importer(s, recorder, generateError: ReloadFailed()).importCertificate(s, certPath: source.cert.path, keyPath: source.key.path)
            XCTFail("expected generate error")
        } catch {
            XCTAssertTrue(error is ReloadFailed)
        }
        XCTAssertTrue(recorder.persisted.isEmpty)
        XCTAssertEqual(try liveCert(s), Data("old-c".utf8))
        XCTAssertFalse(backupExists)
    }

    func testFailedReloadRevertsRecordAndFiles() async throws {
        let s = site()
        try seedPreviousPair(for: s)
        let recorder = Recorder()
        do {
            try await importer(s, recorder, reloadError: ReloadFailed()).importCertificate(s, certPath: source.cert.path, keyPath: source.key.path)
            XCTFail("expected reload failure")
        } catch {
            guard case .reloadFailedReverted = error as? CustomCertificateError else { return XCTFail("\(error)") }
        }
        XCTAssertEqual(recorder.persisted.count, 2)
        XCTAssertNil(recorder.persisted.last?.0)
        XCTAssertEqual(recorder.persisted.last?.1, false)
        XCTAssertEqual(try liveCert(s), Data("old-c".utf8))
        XCTAssertEqual(recorder.reloads, 2)
    }

    func testUncoveredAliasRefusedBeforeAnyFileWrite() async throws {
        let s = site(aliases: ["other.test"])
        let recorder = Recorder()
        do {
            try await importer(s, recorder).importCertificate(s, certPath: source.cert.path, keyPath: source.key.path)
            XCTFail("expected namesNotCovered")
        } catch {
            XCTAssertEqual(error as? CustomCertificateError, .namesNotCovered(["other.test"]))
        }
        XCTAssertFalse(fm.fileExists(atPath: paths.customCertsDir.path))
        XCTAssertEqual(recorder.generated, 0)
    }

    func testRemoveTurnsHTTPSOffAndDeletesFilesEvenWhenReloadFails() async throws {
        let s = site()
        try seedPreviousPair(for: s)
        let recorder = Recorder()
        do {
            try await importer(s, recorder, reloadError: ReloadFailed()).removeCertificate(s)
            XCTFail("expected reload failure")
        } catch {}
        XCTAssertNil(recorder.persisted.first?.0)
        XCTAssertEqual(recorder.persisted.first?.1, false)
        XCTAssertFalse(fm.fileExists(atPath: paths.siteCustomCertDir(s.id.uuidString).path))
    }

    func testRemoveKeepsFilesWhenRenderFails() async throws {
        let s = site()
        try seedPreviousPair(for: s)
        let recorder = Recorder()
        do {
            try await importer(s, recorder, generateError: ReloadFailed()).removeCertificate(s)
            XCTFail("expected generate failure")
        } catch {}
        XCTAssertEqual(try liveCert(s), Data("old-c".utf8))
    }
}
