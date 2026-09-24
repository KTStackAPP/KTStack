import Foundation

extension ShellPathManager {
    public func disable() throws {
        uninstallCLI()
        let patcher = ShellRCPatcher(exportLine: exportLine)
        var firstError: Error?
        for rc in rcFiles {
            do {
                guard let content = try readRC(rc) else { continue }
                let updated = try patcher.contentRemovingBlock(from: content, file: rc.lastPathComponent)
                guard updated != content else { continue }
                try writeRC(updated, to: rc)
            } catch {
                if firstError == nil { firstError = error }
            }
        }
        let fm = FileManager.default
        if fm.fileExists(atPath: paths.shimBinDir.path) { try? fm.removeItem(at: paths.shimBinDir) }
        if let firstError { throw firstError }
    }

    public func latestBackups() -> [URL] {
        let fm = FileManager.default
        return rcFiles.compactMap { rc in
            let dir = rc.deletingLastPathComponent()
            let prefix = "\(rc.lastPathComponent).ktstack.bak-"
            let names = (try? fm.contentsOfDirectory(atPath: dir.path)) ?? []
            return names.filter { $0.hasPrefix(prefix) }.max().map { dir.appendingPathComponent($0) }
        }
    }

    func patch(_ url: URL, with patcher: ShellRCPatcher) throws {
        let content = try readRC(url) ?? ""
        let updated = try patcher.contentWithBlock(in: content, file: url.lastPathComponent)
        try writeRC(updated, to: url)
    }

    func readRC(_ url: URL) throws -> String? {
        let target = url.resolvingSymlinksInPath()
        guard FileManager.default.fileExists(atPath: target.path) else { return nil }
        return try String(contentsOf: target, encoding: .utf8)
    }

    private func writeRC(_ content: String, to url: URL) throws {
        let target = url.resolvingSymlinksInPath()
        try backup(target, beside: url)
        try Data(content.utf8).write(to: target, options: .atomic)
    }

    private func backup(_ target: URL, beside url: URL) throws {
        let fm = FileManager.default
        guard fm.fileExists(atPath: target.path) else { return }
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let base = "\(url.lastPathComponent).ktstack.bak-\(stamp)"
        var dest = url.deletingLastPathComponent().appendingPathComponent(base)
        var suffix = 1
        while fm.fileExists(atPath: dest.path) {
            dest = url.deletingLastPathComponent().appendingPathComponent("\(base)-\(suffix)")
            suffix += 1
        }
        try Data(contentsOf: target).write(to: dest, options: .withoutOverwriting)
    }
}
