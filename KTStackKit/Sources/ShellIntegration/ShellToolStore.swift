import Foundation
import KTStackCore

public final class ShellToolStore: Sendable {
    private let configFile: URL
    private let lock = NSLock()

    public init(paths: AppSupportPaths) {
        self.configFile = paths.shellToolsConfigFile
    }

    public init(configFile: URL) {
        self.configFile = configFile
    }

    public func isEnabled(_ toolId: String, defaultIfMissing: Bool = true) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        let states = loadStatesUnlocked()
        return states[toolId] ?? defaultIfMissing
    }

    public func allStates() -> [String: Bool] {
        lock.lock()
        defer { lock.unlock() }
        return loadStatesUnlocked()
    }

    public func setEnabled(_ toolId: String, enabled: Bool) throws {
        lock.lock()
        defer { lock.unlock() }
        var states = loadStatesUnlocked()
        states[toolId] = enabled
        try saveStatesUnlocked(states)
    }

    public func setSuiteEnabled(_ suite: ShellToolSuite, enabled: Bool) throws {
        lock.lock()
        defer { lock.unlock() }
        var states = loadStatesUnlocked()
        let suiteTools = ShellToolCatalog.tools(for: suite)
        for tool in suiteTools {
            states[tool.id] = enabled
        }
        try saveStatesUnlocked(states)
    }

    private func loadStatesUnlocked() -> [String: Bool] {
        guard let data = try? Data(contentsOf: configFile) else {
            return [:]
        }
        return (try? JSONDecoder().decode([String: Bool].self, from: data)) ?? [:]
    }

    private func saveStatesUnlocked(_ states: [String: Bool]) throws {
        let parentDir = configFile.deletingLastPathComponent()
        let fm = FileManager.default
        if !fm.fileExists(atPath: parentDir.path) {
            try fm.createDirectory(at: parentDir, withIntermediateDirectories: true)
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(states)
        try data.write(to: configFile, options: .atomic)
    }
}
