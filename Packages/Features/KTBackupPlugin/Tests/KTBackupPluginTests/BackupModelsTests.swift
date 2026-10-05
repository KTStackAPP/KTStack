import Foundation
import XCTest
@testable import KTBackupPlugin

final class BackupModelsTests: XCTestCase {
    private func roundTrip<T: Codable & Equatable>(_ value: T) throws -> T {
        let data = try JSONFileStore<T>.encoder.encode(value)
        return try JSONFileStore<T>.decoder.decode(T.self, from: data)
    }

    func testPlanRoundTrip() throws {
        var plan = BackupPlan(name: "Nightly", schedule: BackupSchedule(frequency: .weekly, weekday: 3, hour: 4, minute: 30),
                              keepLast: 5, databases: [.init(engine: "mysql", database: "shop")], includeSites: true,
                              siteIDs: [UUID()], includeSettings: true, destinationID: UUID(), keepLocalCopy: true, skipOnBattery: true)
        plan.setEnabled(true, at: Date(timeIntervalSince1970: 1_700_000_000))
        XCTAssertEqual(try roundTrip(plan), plan)
    }

    func testDestinationRoundTripForEveryKind() throws {
        let destinations = [
            BackupDestination(name: "Disk", kind: .local, local: .init(path: "/Volumes/Backup")),
            BackupDestination(name: "R2", kind: .s3, s3: .init(preset: .cloudflareR2, endpoint: "https://x.r2.cloudflarestorage.com",
                                                                 region: "auto", bucket: "b", prefix: "kt", accessKeyID: "AK", usePathStyle: true)),
            BackupDestination(name: "Drive", kind: .googleDrive, googleDrive: .init(folderID: "f1", folderName: "KTStack Backups",
                                                                                     accountEmail: "a@b.c"),
                              lastTest: .init(testedAt: Date(timeIntervalSince1970: 1_000), succeeded: true, message: "ok"))
        ]
        XCTAssertEqual(try roundTrip(destinations), destinations)
    }

    func testRunRoundTrip() throws {
        let run = BackupRun(planID: UUID(), trigger: .catchUp, startedAt: Date(timeIntervalSince1970: 5), finishedAt: Date(timeIntervalSince1970: 9),
                            status: .partial, items: [.init(kind: .database, name: "mysql/shop", succeeded: false, message: "gone")],
                            archiveName: "a.ktbackup", sizeBytes: 42, sha256: "abc", remoteID: "r", message: "m", warnings: ["w"])
        XCTAssertEqual(try roundTrip(run), run)
    }

    func testPlanDecodesWithMissingOptionalFields() throws {
        let id = UUID()
        let json = Data(#"{"id":"\#(id.uuidString)","name":"Old"}"#.utf8)
        let plan = try JSONFileStore<BackupPlan>.decoder.decode(BackupPlan.self, from: json)
        XCTAssertEqual(plan.id, id)
        XCTAssertFalse(plan.isEnabled)
        XCTAssertEqual(plan.keepLast, BackupPlan.defaultKeepLast)
        XCTAssertEqual(plan.siteExcludes, SiteExcludeDefaults.patterns)
    }

    func testSecretsAreNotPartOfDestinationJSON() throws {
        let destination = BackupDestination(name: "S3", kind: .s3, s3: .init(preset: .aws, endpoint: "https://s3.us-east-1.amazonaws.com",
                                                                              region: "us-east-1", bucket: "b", prefix: "", accessKeyID: "AKID",
                                                                              usePathStyle: false))
        let json = String(decoding: try JSONFileStore<BackupDestination>.encoder.encode(destination), as: UTF8.self)
        XCTAssertFalse(json.lowercased().contains("secret"))
    }

    func testRunStatusFromItems() {
        XCTAssertEqual(BackupRun.status(for: [.init(kind: .database, name: "a", succeeded: true)]), .succeeded)
        XCTAssertEqual(BackupRun.status(for: [.init(kind: .database, name: "a", succeeded: true),
                                              .init(kind: .site, name: "b", succeeded: false)]), .partial)
        XCTAssertEqual(BackupRun.status(for: [.init(kind: .database, name: "a", succeeded: false)]), .failed)
    }
}
