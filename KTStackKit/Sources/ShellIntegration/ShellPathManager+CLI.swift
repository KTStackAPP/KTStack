import Foundation

extension ShellPathManager {
    var cliSource: URL? {
        helperSource?.deletingLastPathComponent().appendingPathComponent("kt")
    }

    public var globalCLI: GlobalCLILink {
        GlobalCLILink(link: globalCLIPath)
    }

    public func installCLI() throws {
        guard isToolEnabled("kt") else {
            uninstallCLI()
            return
        }
        let fm = FileManager.default
        let dir = paths.shimBinDir
        try fm.createDirectory(
            at: dir,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o755]
        )
        guard let cliSource, fm.isExecutableFile(atPath: cliSource.path) else { return }

        let cliDest = dir.appendingPathComponent("kt")
        if fm.fileExists(atPath: cliDest.path) { try? fm.removeItem(at: cliDest) }
        try? fm.copyItem(at: cliSource, to: cliDest)
        try? fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: cliDest.path)
    }

    public func uninstallCLI() {
        try? FileManager.default.removeItem(at: paths.shimBinDir.appendingPathComponent("kt"))
        globalCLI.removeIfManaged()
    }

    public func installGlobalCLI() throws {
        guard let cliSource, FileManager.default.isExecutableFile(atPath: cliSource.path) else {
            throw GlobalCLILink.LinkError.sourceMissing(cliSource?.path ?? "kt")
        }
        try globalCLI.install(target: cliSource)
    }
}
