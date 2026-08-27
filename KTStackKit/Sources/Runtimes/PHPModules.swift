import Foundation
import KTStackCore

public enum PHPModules {
    private final class Cache: @unchecked Sendable {
        let lock = NSLock()
        var byVersion: [String: [String]] = [:]
        var compiledByVersion: [String: [String]] = [:]
    }

    private static let cache = Cache()

    public static func list(version: String, paths: AppSupportPaths = AppSupportPaths()) -> [String] {
        cache.lock.lock()
        if let hit = cache.byVersion[version] { cache.lock.unlock(); return hit }
        cache.lock.unlock()

        let mods = run(version: version, args: ["-m"], paths: paths)
        cache.lock.lock(); cache.byVersion[version] = mods; cache.lock.unlock()
        return mods
    }

    // Modules compiled into the bottle: `php -n -m` ignores ini + scan dir, so it lists only built-ins.
    public static func compiledIn(version: String, paths: AppSupportPaths = AppSupportPaths()) -> [String] {
        cache.lock.lock()
        if let hit = cache.compiledByVersion[version] { cache.lock.unlock(); return hit }
        cache.lock.unlock()

        let mods = run(version: version, args: ["-n", "-m"], paths: paths)
        cache.lock.lock(); cache.compiledByVersion[version] = mods; cache.lock.unlock()
        return mods
    }

    public static func invalidate(version: String) {
        cache.lock.lock()
        cache.byVersion[version] = nil
        cache.compiledByVersion[version] = nil
        cache.lock.unlock()
    }

    public static func loadedModules(
        version: String,
        scanDir: URL,
        paths: AppSupportPaths = AppSupportPaths()
    ) -> [String] {
        var env = ProcessInfo.processInfo.environment
        env["PHP_INI_SCAN_DIR"] = scanDir.path
        return run(version: version, args: ["-m"], env: env, paths: paths)
    }

    private static func run(
        version: String,
        args: [String],
        env: [String: String]? = nil,
        paths: AppSupportPaths
    ) -> [String] {
        let php = paths.phpBinary(version: version)
        guard FileManager.default.isExecutableFile(atPath: php.path) else { return [] }

        let proc = Process()
        proc.executableURL = php
        proc.arguments = args
        if let env { proc.environment = env }
        let out = Pipe()
        proc.standardOutput = out
        proc.standardError = Pipe()
        do { try proc.run() } catch { return [] }
        let data = out.fileHandleForReading.readDataToEndOfFile()
        proc.waitUntilExit()
        guard proc.terminationStatus == 0,
              let text = String(data: data, encoding: .utf8) else { return [] }
        return parse(text)
    }

    static func parse(_ output: String) -> [String] {
        var seen = Set<String>()
        var mods: [String] = []
        for raw in output.split(whereSeparator: \.isNewline) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty, !line.hasPrefix("[") else { continue }
            let name = line.lowercased()
            if seen.insert(name).inserted { mods.append(name) }
        }
        return mods.sorted()
    }
}
