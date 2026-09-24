import KTStackCore
import XCTest
@testable import KTStackKit

final class ShellIntegrationSafetyTests: XCTestCase {
    private var tmp: URL!
    private var home: URL!
    private var link: URL!
    private let fm = FileManager.default

    override func setUpWithError() throws {
        tmp = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("ktstack-shell-safety-\(UUID().uuidString)")
        home = tmp.appendingPathComponent("home")
        link = tmp.appendingPathComponent("bin/kt")
        try fm.createDirectory(at: home, withIntermediateDirectories: true)
        try fm.createDirectory(at: link.deletingLastPathComponent(), withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? fm.removeItem(at: tmp)
    }

    private func makeManager() throws -> ShellPathManager {
        let macOS = tmp.appendingPathComponent("KTStack.app/Contents/MacOS")
        try fm.createDirectory(at: macOS, withIntermediateDirectories: true)
        for name in ["ktstack-resolve", "kt"] {
            let url = macOS.appendingPathComponent(name)
            try "#!/bin/sh\necho \(name)\n".write(to: url, atomically: true, encoding: .utf8)
            try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        }
        return ShellPathManager(
            paths: AppSupportPaths(root: tmp.appendingPathComponent("support")),
            helperSource: macOS.appendingPathComponent("ktstack-resolve"),
            home: home,
            globalCLIPath: link
        )
    }

    private func backups() throws -> [String] {
        try fm.contentsOfDirectory(atPath: home.path).filter { $0.contains(".ktstack.bak-") }
    }

    func testLaunchInstallNeverTouchesGlobalLink() throws {
        let manager = try makeManager()
        try manager.installCLI()
        XCTAssertEqual(manager.globalCLI.state(), .absent, "kt may only reach /usr/local/bin on explicit install")
        XCTAssertTrue(fm.isExecutableFile(atPath: manager.paths.shimBinDir.appendingPathComponent("kt").path))
    }

    func testInstallGlobalCLIRefusesForeignFile() throws {
        let manager = try makeManager()
        try "#!/bin/sh\necho other\n".write(to: link, atomically: true, encoding: .utf8)

        XCTAssertThrowsError(try manager.installGlobalCLI())
        manager.uninstallCLI()

        XCTAssertEqual(try String(contentsOf: link, encoding: .utf8), "#!/bin/sh\necho other\n")
        XCTAssertEqual(manager.globalCLI.state(), .foreign)
    }

    func testInstallGlobalCLIRefusesForeignSymlink() throws {
        let manager = try makeManager()
        try fm.createSymbolicLink(atPath: link.path, withDestinationPath: "/usr/bin/true")

        XCTAssertThrowsError(try manager.installGlobalCLI())
        manager.uninstallCLI()

        XCTAssertEqual(try fm.destinationOfSymbolicLink(atPath: link.path), "/usr/bin/true")
    }

    func testInstallGlobalCLIReplacesManagedLinkAndUninstallRemovesIt() throws {
        let manager = try makeManager()
        try manager.installGlobalCLI()
        XCTAssertEqual(manager.globalCLI.state(), .managed)
        try manager.installGlobalCLI()
        XCTAssertEqual(manager.globalCLI.state(), .managed)

        manager.uninstallCLI()
        XCTAssertEqual(manager.globalCLI.state(), .absent)
    }

    func testDisableLeavesRCWithoutBlockUntouched() throws {
        let manager = try makeManager()
        let bashrc = home.appendingPathComponent(".bashrc")
        try "alias ll='ls -l'\n".write(to: bashrc, atomically: true, encoding: .utf8)

        try manager.disable()

        XCTAssertEqual(try String(contentsOf: bashrc, encoding: .utf8), "alias ll='ls -l'\n")
        XCTAssertEqual(try backups(), [], "rc files without a KTStack block must not be rewritten or backed up")
        XCTAssertFalse(fm.fileExists(atPath: home.appendingPathComponent(".zshrc").path))
    }

    func testEnableKeepsSymlinkedRCAsSymlink() async throws {
        let manager = try makeManager()
        let dotfiles = tmp.appendingPathComponent("dotfiles")
        try fm.createDirectory(at: dotfiles, withIntermediateDirectories: true)
        let real = dotfiles.appendingPathComponent("zshrc")
        try "export EDITOR=vim\n".write(to: real, atomically: true, encoding: .utf8)
        let zshrc = home.appendingPathComponent(".zshrc")
        try fm.createSymbolicLink(atPath: zshrc.path, withDestinationPath: real.path)

        try await manager.enable(provisionComposer: false)

        XCTAssertEqual(try fm.destinationOfSymbolicLink(atPath: zshrc.path), real.path)
        let content = try String(contentsOf: real, encoding: .utf8)
        XCTAssertTrue(content.hasPrefix("export EDITOR=vim\n"))
        XCTAssertTrue(content.contains(ShellRCPatcher.startPrefix))
        XCTAssertFalse(manager.latestBackups().isEmpty)
    }

    func testEnableRefusesUnreadableRCInsteadOfOverwriting() async throws {
        let manager = try makeManager()
        let zshrc = home.appendingPathComponent(".zshrc")
        let original = Data([0x66, 0xFF, 0xFE, 0x0A])
        try original.write(to: zshrc)

        do {
            try await manager.enable(provisionComposer: false)
            XCTFail("enable must fail when an rc file cannot be decoded")
        } catch {}

        XCTAssertEqual(try Data(contentsOf: zshrc), original)
    }
}
