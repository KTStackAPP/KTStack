import Foundation

enum ArchiveTool {
    static let dittoPath = "/usr/bin/ditto"
    static let tarPath = "/usr/bin/tar"

    static func zip(directory: URL, to archive: URL) throws {
        try run(dittoPath, ["-c", "-k", "--keepParent", directory.path, archive.path])
    }

    static func unzip(_ archive: URL, into directory: URL) throws {
        try run(dittoPath, ["-x", "-k", archive.path, directory.path])
    }

    static func run(_ executable: String, _ arguments: [String], currentDirectory: URL? = nil) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        if let currentDirectory {
            process.currentDirectoryURL = currentDirectory
        }
        let errorPipe = Pipe()
        process.standardError = errorPipe
        process.standardOutput = FileHandle.nullDevice
        try process.run()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let detail = String(decoding: errorData, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
            let name = URL(fileURLWithPath: executable).lastPathComponent
            throw BackupPipelineError.toolFailed("\(name) failed: \(detail.isEmpty ? "exit \(process.terminationStatus)" : detail)")
        }
    }
}

public enum BackupPipelineError: Error, LocalizedError, Equatable {
    case alreadyRunning
    case nothingBackedUp(String)
    case toolFailed(String)
    case checksumMismatch
    case invalidArchive(String)

    public var errorDescription: String? {
        switch self {
        case .alreadyRunning: "A backup for this plan is already running."
        case let .nothingBackedUp(detail): "Nothing was backed up: \(detail)"
        case let .toolFailed(detail): detail
        case .checksumMismatch: "The archive checksum doesn't match; the file is damaged or incomplete."
        case let .invalidArchive(detail): "The archive isn't a valid KTStack backup: \(detail)"
        }
    }
}
