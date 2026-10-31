import XCTest
@testable import KTStackKit

final class PHPVersionProbeTests: XCTestCase {
    private var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("kt-php-probe-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)
    }

    private func stub(printing output: String) throws -> (binary: URL, runs: URL) {
        let runs = dir.appendingPathComponent("runs.log")
        let binary = dir.appendingPathComponent("php")
        let script = "#!/bin/sh\necho run >> '\(runs.path)'\necho '\(output)'\n"
        try script.write(to: binary, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: binary.path)
        return (binary, runs)
    }

    func testReadsFullVersion() throws {
        let probe = PHPVersionProbe()
        XCTAssertEqual(probe.fullVersion(at: try stub(printing: "8.5.7").binary), "8.5.7")
    }

    func testRejectsGarbage() throws {
        let probe = PHPVersionProbe()
        XCTAssertNil(probe.fullVersion(at: try stub(printing: "garbage").binary))
    }

    func testCachesByPathAndModificationDate() throws {
        let probe = PHPVersionProbe()
        let (binary, runs) = try stub(printing: "8.4.22")
        XCTAssertEqual(probe.fullVersion(at: binary), "8.4.22")
        XCTAssertEqual(probe.fullVersion(at: binary), "8.4.22")
        let lines = try String(contentsOf: runs, encoding: .utf8).split(whereSeparator: \.isNewline)
        XCTAssertEqual(lines.count, 1)
    }
}
