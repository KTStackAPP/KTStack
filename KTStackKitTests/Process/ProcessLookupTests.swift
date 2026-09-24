import KTStackCore
import XCTest

final class ProcessLookupTests: XCTestCase {
    private var directory: URL!
    private var children: [Process] = []

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ktstack-lookup-\(UUID().uuidString)/bin", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        for child in children where child.isRunning {
            child.terminate()
            child.waitUntilExit()
        }
        try? FileManager.default.removeItem(at: directory.deletingLastPathComponent())
    }

    func testOwnExecutablePathResolves() {
        XCTAssertNotNil(ProcessLookup.executablePath(of: getpid()))
    }

    func testExactPathMatchesOnlyThatBinary() throws {
        let dump = try launchCopy(named: "mysqldump")
        let mysqld = directory.appendingPathComponent("mysqld").path
        XCTAssertFalse(ProcessLookup.pids(executablePath: mysqld).contains(dump.processIdentifier))
        XCTAssertTrue(ProcessLookup.pids(executablePath: dump.executableURL!.path).contains(dump.processIdentifier))
    }

    func testPrefixSiblingIsNotMatched() throws {
        let server = try launchCopy(named: "mysqld")
        let dump = try launchCopy(named: "mysqldump")
        let matches = ProcessLookup.pids(executablePath: directory.appendingPathComponent("mysqld").path)
        XCTAssertEqual(matches, [server.processIdentifier])
        XCTAssertFalse(matches.contains(dump.processIdentifier))
    }

    private func launchCopy(named name: String) throws -> Process {
        let url = directory.appendingPathComponent(name)
        try FileManager.default.copyItem(at: URL(fileURLWithPath: "/bin/sleep"), to: url)
        let proc = Process()
        proc.executableURL = url
        proc.arguments = ["60"]
        try proc.run()
        children.append(proc)
        let deadline = Date().addingTimeInterval(5)
        while ProcessLookup.executablePath(of: proc.processIdentifier) == nil, Date() < deadline {
            usleep(20000)
        }
        return proc
    }
}
