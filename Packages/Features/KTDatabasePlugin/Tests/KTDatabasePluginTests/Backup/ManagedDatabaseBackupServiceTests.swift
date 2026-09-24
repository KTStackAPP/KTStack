import KTPlatformContracts
import KTStackCore
import XCTest
@testable import KTDatabasePlugin

final class ManagedDatabaseBackupServiceTests: XCTestCase {
    private struct EmptyBackupProvider: BackupProvider {
        let fileExtension = "sql"
        let isAvailable = true

        func backup(profile _: ConnectionProfile, password _: String?, database _: String, to artifactURL: URL) async throws {
            FileManager.default.createFile(atPath: artifactURL.path, contents: Data())
        }

        func restore(profile _: ConnectionProfile, password _: String?, from _: URL, into _: RestoreTarget) async throws {}
    }

    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("kt-mbs-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    private func service(installed: Set<DatabaseEngine>, provider: BackupProvider = StubBackupProvider(fileExtension: "sql")) -> ManagedDatabaseBackupService {
        let tools = FakeDatabaseTools(installed: installed)
        let session = BackupSession(library: BackupLibrary(paths: AppSupportPaths(root: root)), tools: tools)
        return ManagedDatabaseBackupService(tools: tools, session: session, providerFor: { _ in provider })
    }

    func testBacksUpWithTheInstalledEngineAndReturnsANonEmptyFile() async throws {
        let artifact = try await service(installed: [.postgres]).backup(database: "shop", engine: nil)
        XCTAssertEqual(artifact.engine, .postgres)
        XCTAssertTrue(artifact.hasContent)
        XCTAssertEqual(try String(contentsOf: artifact.fileURL, encoding: .utf8), "shop")
    }

    func testRefusesAnEngineThatIsNotInstalled() async {
        do {
            _ = try await service(installed: [.postgres]).backup(database: "shop", engine: .mysql)
            XCTFail("an engine that is not installed must be refused")
        } catch {}
    }

    func testRefusesPathLikeDatabaseNames() async {
        for name in ["", "../etc", "a/b"] {
            do {
                _ = try await service(installed: [.mysql]).backup(database: name, engine: nil)
                XCTFail("\(name) must be refused")
            } catch {}
        }
    }

    func testEmptyArtifactIsAnError() async {
        do {
            _ = try await service(installed: [.mysql], provider: EmptyBackupProvider()).backup(database: "shop", engine: nil)
            XCTFail("an empty dump must not be reported as a backup")
        } catch {}
    }
}
