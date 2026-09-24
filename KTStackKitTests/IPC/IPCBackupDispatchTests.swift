import KTPlatformContracts
import KTStackCore
import XCTest
@testable import KTStackKit

final class IPCBackupDispatchTests: XCTestCase {
    private struct FakeBackups: DatabaseBackupProviding {
        let contents: Data?
        let directory: URL
        let calls = CallLog()

        func backup(database: String, engine: DatabaseEngine?) async throws -> DatabaseBackupArtifact {
            calls.record(database, engine)
            guard let contents else { throw CocoaError(.fileWriteUnknown) }
            let url = directory.appendingPathComponent("\(database).sql")
            try contents.write(to: url)
            return DatabaseBackupArtifact(engine: engine ?? .mysql, database: database, fileURL: url)
        }
    }

    private final class CallLog: @unchecked Sendable {
        private let lock = NSLock()
        private var entries: [(String, DatabaseEngine?)] = []

        func record(_ database: String, _ engine: DatabaseEngine?) {
            lock.lock(); entries.append((database, engine)); lock.unlock()
        }

        var last: (String, DatabaseEngine?)? {
            lock.lock(); defer { lock.unlock() }
            return entries.last
        }
    }

    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("kt-bk-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    private func dispatch(_ backups: FakeBackups, _ params: [String: String]) async -> KTIPCResponse {
        let dispatcher = KTIPCCommandDispatcher(
            serverProvider: { nil }, servicesProvider: { nil }, backupProvider: { backups }
        )
        return await dispatcher.dispatch(KTIPCRequest(id: "b", method: "db.backup", params: params))
    }

    func testSuccessfulBackupReturnsTheFilePath() async {
        let backups = FakeBackups(contents: Data("-- dump".utf8), directory: directory)
        let response = await dispatch(backups, ["database": "shop", "engine": "postgres"])
        XCTAssertTrue(response.success, response.error ?? "")
        XCTAssertEqual(response.result, directory.appendingPathComponent("shop.sql").path)
        XCTAssertEqual(backups.calls.last?.0, "shop")
        XCTAssertEqual(backups.calls.last.flatMap { $0.1 }, .postgres)
    }

    func testEmptyBackupFileIsAFailure() async {
        let response = await dispatch(FakeBackups(contents: Data(), directory: directory), ["database": "shop"])
        XCTAssertFalse(response.success)
    }

    func testProviderErrorIsReported() async {
        let response = await dispatch(FakeBackups(contents: nil, directory: directory), ["database": "shop"])
        XCTAssertFalse(response.success)
        XCTAssertTrue(response.error?.contains("shop") == true)
    }

    func testMissingDatabaseAndUnknownEngineAreRejectedBeforeBackingUp() async {
        let backups = FakeBackups(contents: Data("x".utf8), directory: directory)
        let missing = await dispatch(backups, [:])
        XCTAssertFalse(missing.success)
        let unknown = await dispatch(backups, ["database": "shop", "engine": "oracle"])
        XCTAssertFalse(unknown.success)
        XCTAssertTrue(unknown.error?.contains("mysql") == true)
        XCTAssertNil(backups.calls.last)
    }
}
