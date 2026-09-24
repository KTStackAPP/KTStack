import XCTest

final class CLIVersionTests: XCTestCase {
    func testReadsVersionFromEnclosingAppBundleThroughSymlink() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("kt-version-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let contents = root.appendingPathComponent("KTStack.app/Contents", isDirectory: true)
        let macOS = contents.appendingPathComponent("MacOS", isDirectory: true)
        try FileManager.default.createDirectory(at: macOS, withIntermediateDirectories: true)
        let info: [String: Any] = ["CFBundleShortVersionString": "9.8.7", "CFBundleVersion": "65"]
        try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
            .write(to: contents.appendingPathComponent("Info.plist"))
        let executable = macOS.appendingPathComponent("kt")
        FileManager.default.createFile(atPath: executable.path, contents: Data())
        let link = root.appendingPathComponent("kt")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: executable)

        XCTAssertEqual(CLIVersion.current(executable: link), "9.8.7 (build 65)")
    }

    func testUnknownOutsideABundle() {
        XCTAssertEqual(CLIVersion.current(executable: URL(fileURLWithPath: "/usr/bin/true")), "unknown")
    }
}
