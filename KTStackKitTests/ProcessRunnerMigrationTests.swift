import XCTest
@testable import KTStackKit

final class ProcessRunnerMigrationTests: XCTestCase {
    func testTimeoutsMatchThePlan() {
        XCTAssertEqual(ToolTimeout.launchctl, 15)
        XCTAssertEqual(ToolTimeout.processQuery, 5)
        XCTAssertEqual(ToolTimeout.codesign, 30)
        XCTAssertEqual(ToolTimeout.configTest, 10)
    }

    func testLaunchctlReportsFailureWithCombinedOutput() {
        let result = LaunchAgentManager.launchctl(["print", "gui/\(getuid())/com.ktstack.no-such-job-\(UUID().uuidString)"])
        XCTAssertNotEqual(result.code, 0)
        XCTAssertFalse(result.out.isEmpty, "stderr must be surfaced alongside stdout")
    }

    func testCodesignVerificationStillDistinguishesSignedBinaries() throws {
        XCTAssertTrue(BinaryStager.verifySignature(at: URL(fileURLWithPath: "/bin/ls")))
        let script = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("kd-unsigned-\(UUID().uuidString)")
        try "#!/bin/sh\n".write(to: script, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: script) }
        XCTAssertFalse(BinaryStager.verifySignature(at: script))
    }

    func testLsofProbeStillNamesTheListener() throws {
        let fd = socket(AF_INET, SOCK_STREAM, 0)
        defer { close(fd) }
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = 0
        inet_pton(AF_INET, "127.0.0.1", &addr.sin_addr)
        let bound = withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { Darwin.bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) }
        }
        XCTAssertEqual(bound, 0)
        XCTAssertEqual(Darwin.listen(fd, 16), 0)
        var assigned = sockaddr_in()
        var len = socklen_t(MemoryLayout<sockaddr_in>.size)
        withUnsafeMutablePointer(to: &assigned) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { _ = getsockname(fd, $0, &len) }
        }
        let port = Int(UInt16(bigEndian: assigned.sin_port))
        XCTAssertNotNil(PortPreflight.listeningProcess(onPort: port))
        XCTAssertEqual(PortOwnership.listenerPIDs(port: port), [getpid()])
    }
}
