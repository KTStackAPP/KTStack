import KTPlatformContracts
import KTStackCore
import XCTest
@testable import KTStackKit

final class NginxIncludeServiceTests: XCTestCase {
    private final class CallFlag: @unchecked Sendable {
        private let lock = NSLock()
        private var called = false
        func mark() { lock.lock(); called = true; lock.unlock() }
        var wasCalled: Bool { lock.lock(); defer { lock.unlock() }; return called }
    }

    private func makePaths() throws -> AppSupportPaths {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("kd-nginxinc-\(UUID().uuidString)", isDirectory: true)
        let paths = AppSupportPaths(root: root)
        try paths.ensureDirectoryTree()
        return paths
    }

    private func seed(_ contents: String, _ paths: AppSupportPaths) throws {
        try FileManager.default.createDirectory(
            at: paths.nginxConfigDir, withIntermediateDirectories: true
        )
        try contents.write(to: paths.nginxUserConf, atomically: true, encoding: .utf8)
    }

    private func fileContents(_ paths: AppSupportPaths) throws -> String {
        try String(contentsOf: paths.nginxUserConf, encoding: .utf8)
    }

    func testInvalidRevertsAndThrowsRejected() async throws {
        let paths = try makePaths()
        defer { try? FileManager.default.removeItem(at: paths.config.deletingLastPathComponent()) }
        try seed("old", paths)
        let reloadFlag = CallFlag()
        let sut = NginxIncludeService(
            paths: paths,
            validate: { .invalid("boom") },
            reload: { reloadFlag.mark() }
        )
        do {
            try await sut.saveInclude("new")
            XCTFail("expected throw")
        } catch let error as NginxIncludeSaveError {
            XCTAssertEqual(error, .rejected("boom"))
        }
        XCTAssertEqual(try fileContents(paths), "old")
        XCTAssertFalse(reloadFlag.wasCalled)
    }

    func testReloadFailureRevertsAndThrows() async throws {
        let paths = try makePaths()
        defer { try? FileManager.default.removeItem(at: paths.config.deletingLastPathComponent()) }
        try seed("old", paths)
        struct ReloadError: Error {}
        let sut = NginxIncludeService(
            paths: paths,
            validate: { .valid },
            reload: { throw ReloadError() }
        )
        do {
            try await sut.saveInclude("new")
            XCTFail("expected throw")
        } catch let error as NginxIncludeSaveError {
            guard case .reloadFailedReverted = error else { return XCTFail("wrong case") }
        }
        XCTAssertEqual(try fileContents(paths), "old")
    }

    func testCouldNotValidateKeepsFile() async throws {
        let paths = try makePaths()
        defer { try? FileManager.default.removeItem(at: paths.config.deletingLastPathComponent()) }
        try seed("old", paths)
        let sut = NginxIncludeService(
            paths: paths,
            validate: { .couldNotRun },
            reload: {}
        )
        do {
            try await sut.saveInclude("new")
            XCTFail("expected throw")
        } catch let error as NginxIncludeSaveError {
            XCTAssertEqual(error, .couldNotValidate)
        }
        XCTAssertEqual(try fileContents(paths), "new")
    }

    func testValidReloadOKPersistsAndBackup() async throws {
        let paths = try makePaths()
        defer { try? FileManager.default.removeItem(at: paths.config.deletingLastPathComponent()) }
        try seed("old", paths)
        let sut = NginxIncludeService(
            paths: paths,
            validate: { .valid },
            reload: {}
        )
        try await sut.saveInclude("new")
        XCTAssertEqual(try fileContents(paths), "new")
        let bak = paths.nginxUserConf.appendingPathExtension("bak")
        XCTAssertEqual(try String(contentsOf: bak, encoding: .utf8), "old")
    }

    func testReadIncludeSeedsTemplate() throws {
        let paths = try makePaths()
        defer { try? FileManager.default.removeItem(at: paths.config.deletingLastPathComponent()) }
        let sut = NginxIncludeService(paths: paths, validate: { .valid }, reload: {})
        XCTAssertEqual(try sut.readInclude(), NginxUserIncludeTemplate.default)
    }
}
