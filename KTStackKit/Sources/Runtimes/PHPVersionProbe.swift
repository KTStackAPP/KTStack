import Foundation

// Đọc PHP_VERSION của binary đã cài, cache theo path + ngày sửa file.
public final class PHPVersionProbe: @unchecked Sendable {
    private struct Key: Hashable {
        let path: String
        let modified: Date
    }

    private let lock = NSLock()
    private var cache: [Key: String] = [:]

    public init() {}

    public func fullVersion(at binary: URL) -> String? {
        guard let modified = try? binary.resourceValues(forKeys: [.contentModificationDateKey])
            .contentModificationDate else { return nil }
        let key = Key(path: binary.path, modified: modified)
        lock.lock()
        if let hit = cache[key] { lock.unlock(); return hit }
        lock.unlock()

        guard let version = run(binary) else { return nil }
        lock.lock()
        cache[key] = version
        lock.unlock()
        return version
    }

    private func run(_ binary: URL) -> String? {
        guard FileManager.default.isExecutableFile(atPath: binary.path) else { return nil }
        let proc = Process()
        proc.executableURL = binary
        proc.arguments = ["-n", "-r", "echo PHP_VERSION;"]
        let out = Pipe()
        proc.standardOutput = out
        proc.standardError = Pipe()
        do { try proc.run() } catch { return nil }
        let data = out.fileHandleForReading.readDataToEndOfFile()
        proc.waitUntilExit()
        guard proc.terminationStatus == 0,
              let text = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
              text.range(of: #"^\d+\.\d+\.\d+"#, options: .regularExpression) != nil else { return nil }
        return text
    }
}
