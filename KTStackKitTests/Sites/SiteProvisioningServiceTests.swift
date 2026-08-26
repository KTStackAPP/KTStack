import KTPlatformContracts
import KTStackCore
import XCTest
@testable import KTStackKit

@MainActor
final class SiteProvisioningServiceTests: XCTestCase {
    private let fm = FileManager.default

    private struct ThrowingInstaller: SiteInstaller {
        struct Boom: Error {}
        func scaffold(into _: URL, request _: NewSiteRequest, emit _: @Sendable (String) -> Void) async throws {
            throw Boom()
        }
    }

    private func makeRegistry() throws -> (SiteRegistry, URL) {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("kd-prov-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        let store = root.appendingPathComponent("sites.json")
        return (SiteRegistry(storeURL: store, tld: "test"), root)
    }

    private func service(
        registry: SiteRegistry,
        databaseExists: @escaping @Sendable (String) async throws -> Bool = { _ in false },
        createDatabase: @escaping @Sendable (String) async throws -> Void = { _ in },
        dropDatabase: @escaping @Sendable (String) async throws -> Void = { _ in },
        makeInstaller: @escaping @Sendable (NewSiteRequest) async throws -> SiteInstaller = { _ in ThrowingInstaller() },
        performRestore: @escaping @Sendable @MainActor (Site, RestoreRequest, @escaping @Sendable (RestoreEvent) -> Void) async throws -> RestoreOutcome = { site, _, _ in RestoreOutcome(domain: site.domain, warnings: []) }
    ) -> SiteProvisioningService {
        SiteProvisioningService(
            registry: registry,
            database: DatabaseProvisioner(ensureEngine: {}),
            databaseExists: databaseExists,
            createDatabase: createDatabase,
            dropDatabase: dropDatabase,
            ensureSeededIni: { _ in },
            makeInstaller: makeInstaller,
            enableHTTPSForSite: { _ in },
            performRestore: performRestore,
            resolveSafeDocroot: { $0 }
        )
    }

    func testInstallRollsBackFolderWhenScaffoldThrows() async throws {
        let (registry, root) = try makeRegistry()
        defer { try? fm.removeItem(at: root) }
        let folder = root.appendingPathComponent("roll", isDirectory: true)
        let request = NewSiteRequest(
            name: "roll", kind: .empty, phpVersion: "8.3",
            folder: folder, domain: "roll.test", databaseName: nil
        )
        let sut = service(registry: registry)

        do {
            _ = try await sut.install(request, enableHTTPS: false, emit: { _ in })
            XCTFail("expected scaffold failure")
        } catch {}

        XCTAssertFalse(fm.fileExists(atPath: folder.path))
        XCTAssertTrue(registry.sites.isEmpty)
    }

    func testImportRejectsExistingDatabase() async throws {
        let (registry, root) = try makeRegistry()
        defer { try? fm.removeItem(at: root) }
        let folder = root.appendingPathComponent("shop", isDirectory: true)
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)
        let sut = service(registry: registry, databaseExists: { _ in true })

        do {
            _ = try await sut.importFolder(folder, domain: "shop.test", phpVersion: "8.3",
                                           createDatabase: true, enableHTTPS: false)
            XCTFail("expected databaseExists rejection")
        } catch let error as SiteImportError {
            guard case .databaseExists = error else { return XCTFail("wrong case: \(error)") }
        }
        XCTAssertTrue(registry.sites.isEmpty)
    }

    func testRemoveRunsFolderThenDatabaseThenRecord() async throws {
        let (registry, root) = try makeRegistry()
        defer { try? fm.removeItem(at: root) }
        let folder = root.appendingPathComponent("gone", isDirectory: true)
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)
        try "<?php".write(to: folder.appendingPathComponent("index.php"), atomically: true, encoding: .utf8)
        let site = try registry.add(folder: folder, databaseName: "gone_db")

        let order = OrderRecorder()
        let sut = service(registry: registry, dropDatabase: { _ in await order.append("db") })
        // Ghi mốc folder/record quanh remove để xác nhận thứ tự folder → DB → record.
        await order.append("start")
        try await sut.remove(site.id, deleteFolder: true, dropDatabase: true)

        XCTAssertFalse(fm.fileExists(atPath: folder.path))
        XCTAssertTrue(registry.sites.isEmpty)
        let seq = await order.values
        XCTAssertEqual(seq, ["start", "db"])
    }

    func testRestoreForwardsResolvedSiteID() async throws {
        let (registry, root) = try makeRegistry()
        defer { try? fm.removeItem(at: root) }
        let folder = root.appendingPathComponent("blog", isDirectory: true)
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)
        try "<?php".write(to: folder.appendingPathComponent("index.php"), atomically: true, encoding: .utf8)
        let site = try registry.add(folder: folder)

        let captured = IDBox()
        let sut = service(registry: registry, performRestore: { site, _, _ in
            await captured.set(site.id)
            return RestoreOutcome(domain: site.domain, warnings: [])
        })
        let request = RestoreRequest(
            backupFile: folder.appendingPathComponent("dump.zip"), siteFolder: folder,
            siteDomain: site.domain, phpVersion: "8.3", secure: false, repairEncoding: false
        )
        _ = try await sut.restore(request, into: site.id, emit: { _ in })
        let got = await captured.value
        XCTAssertEqual(got, site.id)
    }

    func testRestoreThrowsWhenSiteMissing() async throws {
        let (registry, root) = try makeRegistry()
        defer { try? fm.removeItem(at: root) }
        let sut = service(registry: registry)
        let request = RestoreRequest(
            backupFile: root.appendingPathComponent("dump.zip"), siteFolder: root,
            siteDomain: "ghost.test", phpVersion: "8.3", secure: false, repairEncoding: false
        )
        do {
            _ = try await sut.restore(request, into: UUID(), emit: { _ in })
            XCTFail("expected sourceURLUnresolved")
        } catch {}
    }
}

private actor OrderRecorder {
    private(set) var values: [String] = []
    func append(_ v: String) { values.append(v) }
}

private actor IDBox {
    private(set) var value: UUID?
    func set(_ v: UUID) { value = v }
}
