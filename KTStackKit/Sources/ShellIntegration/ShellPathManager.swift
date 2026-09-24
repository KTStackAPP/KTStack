import Foundation
import KTStackCore

public final class ShellPathManager: @unchecked Sendable {
    public struct Status: Sendable, Equatable {
        public let enabled: Bool
        public let shellsPatched: [String]
        public let toolStates: [String: Bool]
        public let installedTools: Set<String>

        public init(
            enabled: Bool,
            shellsPatched: [String],
            toolStates: [String: Bool] = [:],
            installedTools: Set<String> = []
        ) {
            self.enabled = enabled
            self.shellsPatched = shellsPatched
            self.toolStates = toolStates
            self.installedTools = installedTools
        }

        public func isToolEnabled(_ toolId: String) -> Bool {
            toolStates[toolId] ?? true
        }

        public func isToolInstalled(_ toolId: String) -> Bool {
            installedTools.contains(toolId)
        }
    }

    public enum ShellError: LocalizedError {
        case ownership(String)
        case helperMissing(String)
        public var errorDescription: String? {
            switch self {
            case let .ownership(path): "Refusing to use shim directory \(path): it is not owned by the current user."
            case let .helperMissing(path): "Resolver helper not found at \(path)."
            }
        }
    }

    let paths: AppSupportPaths
    let helperSource: URL?
    let globalCLIPath: URL
    private let home: URL
    private let toolStore: ShellToolStore
    private let toolResolver: ShellToolResolver

    public init(
        paths: AppSupportPaths,
        helperSource: URL? = nil,
        home: URL = FileManager.default.homeDirectoryForCurrentUser,
        globalCLIPath: URL = GlobalCLILink.defaultPath
    ) {
        self.paths = paths
        self.helperSource = helperSource
        self.globalCLIPath = globalCLIPath
        self.home = home
        self.toolStore = ShellToolStore(paths: paths)
        self.toolResolver = ShellToolResolver(paths: paths)
    }

    var exportLine: String {
        "export PATH=\"\(paths.shimBinDir.path):$PATH\""
    }

    var rcFiles: [URL] {
        let fm = FileManager.default
        var files = [home.appendingPathComponent(".zshrc"), home.appendingPathComponent(".zprofile")]
        for candidate in [".bashrc", ".bash_profile"] {
            let url = home.appendingPathComponent(candidate)
            if fm.fileExists(atPath: url.path) { files.append(url) }
        }
        return files
    }

    public func enable(provisionComposer: Bool = true) async throws {
        try prepareShimDir()
        try ShellShimWriter(paths: paths).writeShims()
        if provisionComposer {
            do {
                _ = try await ComposerProvisioner(paths: paths).provision()
            } catch {
                NSLog("KTStack: composer provisioning skipped — \(error.localizedDescription)")
            }
        }
        let patcher = ShellRCPatcher(exportLine: exportLine)
        for rc in rcFiles {
            try patch(rc, with: patcher)
        }
    }

    public func refreshStagedShimIfEnabled() throws {
        guard FileManager.default.fileExists(
            atPath: paths.shimBinDir.appendingPathComponent("ktstack-resolve").path
        ) else { return }
        try prepareShimDir()
        try ShellShimWriter(paths: paths).writeShims()
    }
    public func composerProvisioned() -> Bool {
        ComposerProvisioner(paths: paths).isProvisioned
    }

    public func isToolEnabled(_ toolId: String) -> Bool {
        toolStore.isEnabled(toolId)
    }

    public func setToolEnabled(_ toolId: String, enabled: Bool) throws {
        try toolStore.setEnabled(toolId, enabled: enabled)
        if toolId == "kt" {
            if enabled {
                try? installCLI()
            } else {
                uninstallCLI()
            }
        }
    }

    public func setSuiteEnabled(_ suite: ShellToolSuite, enabled: Bool) throws {
        try toolStore.setSuiteEnabled(suite, enabled: enabled)
        if suite == .ktstack {
            if enabled {
                try? installCLI()
            } else {
                uninstallCLI()
            }
        }
    }

    public func isToolInstalled(_ tool: ShellTool) -> Bool {
        toolResolver.isInstalled(tool.command)
    }

    public func status() -> Status {
        let patcher = ShellRCPatcher(exportLine: exportLine)
        var patched: [String] = []
        for rc in rcFiles {
            guard let content = try? String(contentsOf: rc, encoding: .utf8) else { continue }
            if patcher.containsValidBlock(in: content, file: rc.lastPathComponent) {
                patched.append(rc.lastPathComponent)
            }
        }
        let helperReady = FileManager.default.fileExists(
            atPath: paths.shimBinDir.appendingPathComponent("ktstack-resolve").path
        )
        let toolStates = toolStore.allStates()
        var installed = Set<String>()
        for tool in ShellToolCatalog.tools where toolResolver.isInstalled(tool.command) {
            installed.insert(tool.id)
        }
        return Status(
            enabled: helperReady && !patched.isEmpty,
            shellsPatched: patched,
            toolStates: toolStates,
            installedTools: installed
        )
    }

    private func prepareShimDir() throws {
        let fm = FileManager.default
        let dir = paths.shimBinDir
        try fm.createDirectory(
            at: dir,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o755]
        )
        try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: dir.path)
        let attrs = try fm.attributesOfItem(atPath: dir.path)
        if let owner = attrs[.ownerAccountID] as? NSNumber, owner.uint32Value != getuid() {
            throw ShellError.ownership(dir.path)
        }
        guard let helperSource, fm.isExecutableFile(atPath: helperSource.path) else {
            throw ShellError.helperMissing(helperSource?.path ?? "ktstack-resolve")
        }
        let dest = dir.appendingPathComponent("ktstack-resolve")
        if fm.fileExists(atPath: dest.path) { try fm.removeItem(at: dest) }
        try fm.copyItem(at: helperSource, to: dest)
        try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: dest.path)
        if isToolEnabled("kt") {
            try? installCLI()
        } else {
            uninstallCLI()
        }
    }
}
