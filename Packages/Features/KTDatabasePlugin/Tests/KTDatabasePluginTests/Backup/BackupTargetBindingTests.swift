import KTStackCore
import XCTest
@testable import KTDatabasePlugin

final class BackupTargetBindingTests: XCTestCase {
    private let remote = ConnectionProfile(
        name: "Staging", kind: .mysql, host: "db.staging.internal", port: 3307, user: "app", database: "shop"
    )

    private func set(profileID: UUID?) -> BackupSet {
        BackupSet(
            kind: .mysql, engineVersion: nil, profileName: "Local MySQL", host: "127.0.0.1",
            profileID: profileID, port: 3306, databases: ["shop"]
        )
    }

    func testLibraryRecordsTheSourceProfile() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("kt-bind-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let paths = AppSupportPaths(root: root)
        try paths.ensureDirectoryTree()
        let created = try await BackupLibrary(paths: paths).create(
            kind: .mysql, profile: remote, databases: ["shop"], using: StubBackupProvider(), password: nil
        )
        XCTAssertEqual(created.profileID, remote.id)
        XCTAssertEqual(created.port, 3307)
        XCTAssertTrue(created.belongs(to: remote))
    }

    func testLegacyMetadataDecodesWithoutProfile() throws {
        let legacy = #"{"id":"\#(UUID().uuidString)","kind":"mysql","profileName":"Local","host":"127.0.0.1","databases":["a"],"createdAt":0,"sizeBytes":1}"#
        let decoded = try JSONDecoder().decode(BackupSet.self, from: Data(legacy.utf8))
        XCTAssertNil(decoded.profileID)
        XCTAssertNotNil(decoded.targetWarning(for: remote))
    }

    func testWarningNamesTheTargetHostForOtherProfiles() throws {
        XCTAssertNil(set(profileID: remote.id).targetWarning(for: remote))
        let warning = try XCTUnwrap(set(profileID: UUID()).targetWarning(for: remote))
        XCTAssertTrue(warning.contains("db.staging.internal:3307"), warning)
        XCTAssertTrue(warning.contains("127.0.0.1:3306"), warning)
    }

    func testRestoreRefusesAnotherConnectionUntilConfirmed() async {
        let session = BackupSession(tools: FakeDatabaseTools())
        let foreign = set(profileID: UUID())
        do {
            try await session.restore(set: foreign, database: "shop", profile: remote, password: nil, target: .overwrite)
            XCTFail("a cross-connection restore must need confirmation")
        } catch {
            XCTAssertTrue((error as? DatabaseError)?.message.contains("different connection") == true)
        }
        do {
            try await session.restore(
                set: foreign, database: "shop", profile: remote, password: nil, target: .overwrite, confirmedTarget: true
            )
        } catch {
            XCTAssertFalse((error as? DatabaseError)?.message.contains("different connection") == true)
        }
    }
}
