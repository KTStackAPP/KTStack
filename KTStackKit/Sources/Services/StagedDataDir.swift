import Foundation

enum StagedDataDir {
    struct LeftoverData: LocalizedError {
        let path: String
        var errorDescription: String? {
            "\(path) holds files from an earlier failed initialization. Use Reset Data to move them aside, then start again."
        }
    }

    struct Incomplete: LocalizedError {
        let tool: String
        var errorDescription: String? { "\(tool) finished without creating a usable data directory." }
    }

    static func initialize(_ dataDir: URL, marker: String, tool: String, populate: (URL) throws -> Void) throws {
        let fm = FileManager.default
        if ServiceInitializer.isInitialized(dataDir, marker: marker) { return }
        let parent = dataDir.deletingLastPathComponent()
        try ServiceInitializer.ensureDir(parent)
        if fm.fileExists(atPath: dataDir.path), try !fm.contentsOfDirectory(atPath: dataDir.path).isEmpty {
            throw LeftoverData(path: dataDir.path)
        }
        let staging = parent.appendingPathComponent(".\(dataDir.lastPathComponent).initializing-\(UUID().uuidString)")
        defer { try? fm.removeItem(at: staging) }
        try populate(staging)
        guard ServiceInitializer.isInitialized(staging, marker: marker) else { throw Incomplete(tool: tool) }
        if fm.fileExists(atPath: dataDir.path) { try fm.removeItem(at: dataDir) }
        try fm.moveItem(at: staging, to: dataDir)
        try fm.setAttributes([.posixPermissions: 0o700], ofItemAtPath: dataDir.path)
    }
}
