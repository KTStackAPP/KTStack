import Foundation
import XCTest
@testable import KTBackupPlugin

final class LocalFolderClientTests: XCTestCase {
    private func archive(in directory: URL, plan: BackupPlan, at stamp: Date) throws -> BackupUploadRequest {
        let name = BackupArchiveNaming.fileName(for: plan, at: stamp)
        let file = directory.appendingPathComponent(name)
        try Data("archive \(stamp.timeIntervalSince1970)".utf8).write(to: file)
        return BackupUploadRequest(fileURL: file, fileName: name, planFolderName: BackupArchiveNaming.folderName(for: plan),
                                   planID: plan.id, sha256: try FileDigest.sha256Hex(of: file), sizeBytes: try FileDigest.size(of: file))
    }

    private func movingTrash(into trash: URL) -> LocalFolderClient.TrashHandler {
        { url in try FileManager.default.moveItem(at: url, to: trash.appendingPathComponent(url.lastPathComponent)) }
    }

    func testUploadVerifiesAndListsOwnedArchives() async throws {
        let staging = try makeTemporaryDirectory()
        let folder = try makeTemporaryDirectory()
        let plan = BackupPlan(name: "Shop DB")
        let request = try archive(in: staging, plan: plan, at: date("2026-05-10 02:00:00"))
        let client = LocalFolderClient(folder: folder)
        let object = try await client.upload(request) { _ in }
        XCTAssertEqual(object.sha256, request.sha256)
        XCTAssertEqual(object.sizeBytes, request.sizeBytes)
        XCTAssertEqual(URL(fileURLWithPath: object.id).deletingLastPathComponent().lastPathComponent, "Shop DB")
        let listed = try await client.list(ownedBy: plan.id)
        XCTAssertEqual(listed, [object])
        let other = try await client.list(ownedBy: UUID())
        XCTAssertTrue(other.isEmpty)
    }

    func testRetentionKeepsLastNAndLeavesForeignFiles() async throws {
        let staging = try makeTemporaryDirectory()
        let folder = try makeTemporaryDirectory()
        let trash = try makeTemporaryDirectory()
        let plan = BackupPlan(name: "Nightly")
        let client = LocalFolderClient(folder: folder, trash: movingTrash(into: trash))
        for day in 1...5 {
            _ = try await client.upload(try archive(in: staging, plan: plan, at: date("2026-05-0\(day) 02:00:00"))) { _ in }
        }
        let planFolder = folder.appendingPathComponent("Nightly")
        try Data("mine".utf8).write(to: planFolder.appendingPathComponent("notes.txt"))
        let otherPlan = BackupPlan(name: "Nightly")
        _ = try await client.upload(try archive(in: staging, plan: otherPlan, at: date("2026-04-01 02:00:00"))) { _ in }
        let warnings = await BackupRetention.prune(client, planID: plan.id, keepLast: 2)
        XCTAssertEqual(warnings, [])
        let remaining = try await client.list(ownedBy: plan.id).compactMap(\.createdAt).sorted()
        XCTAssertEqual(remaining, [date("2026-05-04 02:00:00"), date("2026-05-05 02:00:00")])
        XCTAssertTrue(FileManager.default.fileExists(atPath: planFolder.appendingPathComponent("notes.txt").path))
        let otherCount = try await client.list(ownedBy: otherPlan.id).count
        XCTAssertEqual(otherCount, 1)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: trash.path).filter { $0.hasSuffix(".ktbackup") }.count, 3)
    }

    func testMissingFolderFailsWithClearMessage() async throws {
        let staging = try makeTemporaryDirectory()
        let client = LocalFolderClient(folder: staging.appendingPathComponent("Unmounted Volume"))
        do {
            _ = try await client.upload(try archive(in: staging, plan: BackupPlan(name: "P"), at: Date())) { _ in }
            XCTFail("expected failure")
        } catch let error as BackupDestinationError {
            XCTAssertTrue(error.localizedDescription.contains("isn't available"))
        }
    }

    func testVolumeWithoutTrashSkipsPruningWithWarning() async throws {
        let staging = try makeTemporaryDirectory()
        let folder = try makeTemporaryDirectory()
        let plan = BackupPlan(name: "NAS")
        let client = LocalFolderClient(folder: folder) { _ in throw CocoaError(.featureUnsupported) }
        for day in 1...3 {
            _ = try await client.upload(try archive(in: staging, plan: plan, at: date("2026-05-0\(day) 02:00:00"))) { _ in }
        }
        let warnings = await BackupRetention.prune(client, planID: plan.id, keepLast: 1)
        XCTAssertEqual(warnings.count, 1)
        let count = try await client.list(ownedBy: plan.id).count
        XCTAssertEqual(count, 3)
    }

    func testConnectionReportsWritableFolder() async throws {
        let message = try await LocalFolderClient(folder: try makeTemporaryDirectory()).testConnection()
        XCTAssertTrue(message.hasPrefix("Folder is writable"))
    }
}
