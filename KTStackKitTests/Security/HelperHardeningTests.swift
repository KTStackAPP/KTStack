import Foundation
import KTStackCore
import XCTest
@testable import KTStackKit

final class HelperHardeningTests: XCTestCase {
    private var dir: URL!

    override func setUpWithError() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("kt-helper-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)
    }

    func testRejectedBinaryNeverReplacesTheInstalledOne() throws {
        let destination = dir.appendingPathComponent("dnsmasq")
        try Data("trusted".utf8).write(to: destination)
        XCTAssertThrowsError(
            try StagedBinaryInstaller.install(Data("evil".utf8), to: destination, mode: 0o755, verify: { _ in false })
        )
        XCTAssertEqual(try String(contentsOf: destination, encoding: .utf8), "trusted")
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: dir.path), ["dnsmasq"])
    }

    func testVerifiedBinaryIsRenamedIntoPlaceWithItsMode() throws {
        let destination = dir.appendingPathComponent("bin/dnsmasq")
        var checked: URL?
        try StagedBinaryInstaller.install(Data("good".utf8), to: destination, mode: 0o755) { url in
            checked = url
            return true
        }
        XCTAssertNotEqual(checked, destination)
        XCTAssertEqual(checked?.deletingLastPathComponent(), destination.deletingLastPathComponent())
        XCTAssertEqual(try String(contentsOf: destination, encoding: .utf8), "good")
        let mode = try FileManager.default.attributesOfItem(atPath: destination.path)[.posixPermissions] as? NSNumber
        XCTAssertEqual(mode?.intValue, 0o755)
    }

    func testTeamRequirementPinsTheTeam() {
        XCTAssertEqual(
            HelperIdentity.teamRequirement(for: " ABCDE12345 "),
            "anchor apple generic and certificate leaf[subject.OU] = \"ABCDE12345\""
        )
        XCTAssertNil(HelperIdentity.teamRequirement(for: ""))
        XCTAssertEqual(HelperIdentity.resolvedTeamID(), HelperIdentity.teamID)
    }

    func testCodesignVerificationCarriesTheRequirementWhenGiven() {
        let url = URL(fileURLWithPath: "/tmp/x")
        XCTAssertEqual(BinaryStager.codesignArguments(for: url, requirement: nil), ["--verify", "--strict", "/tmp/x"])
        XCTAssertEqual(
            BinaryStager.codesignArguments(for: url, requirement: "anchor apple generic"),
            ["--verify", "--strict", "-R", "anchor apple generic", "/tmp/x"]
        )
    }

    func testAdminScriptRunsInlineAndRoundTripsThroughAppleScript() throws {
        let installer = SudoFallbackInstaller(bundledDnsmasq: URL(fileURLWithPath: "/tmp/it's \"dns\"\\masq"))
        let script = installer.installScript()
        let command = SudoFallbackInstaller.appleScriptCommand(for: script)
        XCTAssertFalse(command.contains("install.sh"))
        XCTAssertFalse(command.contains(NSTemporaryDirectory()))
        let prefix = "do shell script \"/bin/bash -c \" & quoted form of \""
        let suffix = "\" with administrator privileges"
        XCTAssertTrue(command.hasPrefix(prefix))
        XCTAssertTrue(command.hasSuffix(suffix))
        let literal = String(command.dropFirst(prefix.count).dropLast(suffix.count))
        XCTAssertFalse(literal.contains("\n"))
        XCTAssertEqual(Self.appleScriptUnescape(literal), script)
    }

    private static func appleScriptUnescape(_ literal: String) -> String {
        var result = ""
        var escaping = false
        for character in literal {
            if escaping {
                result.append(character == "n" ? "\n" : character)
                escaping = false
            } else if character == "\\" {
                escaping = true
            } else {
                result.append(character)
            }
        }
        return result
    }
}
