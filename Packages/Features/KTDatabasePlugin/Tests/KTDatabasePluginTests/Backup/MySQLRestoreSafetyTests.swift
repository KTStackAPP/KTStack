import XCTest
@testable import KTDatabasePlugin

final class MySQLRestoreSafetyTests: XCTestCase {
    private var root: URL!
    private var toolDir: URL!
    private var safetyDir: URL!
    private var argsLog: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("ktstack-restore-safety-\(UUID().uuidString)")
        toolDir = root.appendingPathComponent("tools", isDirectory: true)
        safetyDir = root.appendingPathComponent("safety", isDirectory: true)
        argsLog = root.appendingPathComponent("mysqldump-args.log")
        try FileManager.default.createDirectory(at: toolDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    private func installTools(rollbackExit: Int32) throws {
        try tool("mysqldump", """
        echo "$@" > '\(argsLog.path)'
        echo '-- SAFETY original rows'
        """)
        try tool("mysql", """
        input=$(cat)
        case "$input" in
          *NEW-ARTIFACT*) echo 'syntax error in artifact' >&2; exit 1 ;;
          *SAFETY*) exit \(rollbackExit) ;;
        esac
        exit 0
        """)
    }

    private func tool(_ name: String, _ body: String) throws {
        let url = toolDir.appendingPathComponent(name)
        try "#!/bin/sh\n\(body)\n".write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
    }

    private func artifact() throws -> URL {
        let url = root.appendingPathComponent("shop.sql")
        try "-- NEW-ARTIFACT broken".write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private func provider() -> MySQLBackupProvider {
        let service = DumpService(tools: FakeDatabaseTools(), systemToolSearchPaths: [toolDir])
        return MySQLBackupProvider(dumpService: service, safetyDirectory: safetyDir)
    }

    private func safetyFiles() -> [String] {
        (try? FileManager.default.contentsOfDirectory(atPath: safetyDir.path)) ?? []
    }

    func testFailedRollbackKeepsSafetyDumpAndSaysSo() async throws {
        try installTools(rollbackExit: 1)
        do {
            try await provider().restore(profile: .managedMySQL, password: nil, from: try artifact(), into: .overwrite)
            XCTFail("restore must fail")
        } catch {
            let message = (error as? DatabaseError)?.message ?? ""
            XCTAssertFalse(message.contains("was rolled back"), message)
            XCTAssertTrue(message.contains("also failed"), message)
            let kept = try XCTUnwrap(safetyFiles().first)
            XCTAssertTrue(message.contains(safetyDir.appendingPathComponent(kept).path), message)
        }
        XCTAssertEqual(safetyFiles().count, 1)
    }

    func testSuccessfulRollbackReportsItAndCleansUp() async throws {
        try installTools(rollbackExit: 0)
        do {
            try await provider().restore(profile: .managedMySQL, password: nil, from: try artifact(), into: .overwrite)
            XCTFail("restore must fail")
        } catch {
            let message = (error as? DatabaseError)?.message ?? ""
            XCTAssertTrue(message.contains("was rolled back"), message)
            XCTAssertTrue(message.contains("syntax error in artifact"), message)
        }
        XCTAssertTrue(safetyFiles().isEmpty)
    }

    func testSafetyDumpIncludesRoutinesEventsAndTriggers() async throws {
        try installTools(rollbackExit: 0)
        _ = try? await provider().restore(profile: .managedMySQL, password: nil, from: try artifact(), into: .overwrite)
        let args = try String(contentsOf: argsLog, encoding: .utf8)
        for flag in ["--routines", "--events", "--triggers", "--set-gtid-purged=OFF", "--single-transaction"] {
            XCTAssertTrue(args.contains(flag), "\(flag) missing from: \(args)")
        }
    }

    func testDumpArgumentsSkipGTIDFlagForMariaDBAndRoutinesForSingleTable() {
        let maria = DumpService.dumpArguments(defaultsPath: "/d", database: "shop", table: nil, isMariaDB: true)
        XCTAssertFalse(maria.contains("--set-gtid-purged=OFF"))
        XCTAssertTrue(maria.contains("--routines"))
        let table = DumpService.dumpArguments(defaultsPath: "/d", database: "shop", table: "users", isMariaDB: false)
        XCTAssertEqual(Array(table.suffix(3)), ["--", "shop", "users"])
        XCTAssertFalse(table.contains("--routines"))
        XCTAssertTrue(table.contains("--triggers"))
    }
}
