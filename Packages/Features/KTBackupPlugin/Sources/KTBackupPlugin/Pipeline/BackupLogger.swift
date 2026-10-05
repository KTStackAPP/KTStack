import Foundation

public final class BackupLogger: @unchecked Sendable {
    private let fileURL: URL
    private let lock = NSLock()
    private let formatter = ISO8601DateFormatter()

    public init(fileURL: URL) {
        self.fileURL = fileURL
    }

    public func log(_ message: String, at date: Date = Date()) {
        lock.lock()
        defer { lock.unlock() }
        let line = Data("[\(formatter.string(from: date))] \(message)\n".utf8)
        try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let handle = try? FileHandle(forWritingTo: fileURL) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: line)
        } else {
            try? line.write(to: fileURL)
        }
    }
}
