import Foundation
import KTStackCore

enum RestoreShellTools {
    private static let unzip = URL(fileURLWithPath: "/usr/bin/unzip")
    private static let gunzip = URL(fileURLWithPath: "/usr/bin/gunzip")

    static func zipEntries(_ archive: URL) throws -> [String] {
        let output = try run(unzip, ["-Z1", archive.path])
        return output.split(separator: "\n").map(String.init)
    }

    static func unzip(_ archive: URL, into destination: URL) throws {
        _ = try run(unzip, ["-qq", "-o", archive.path, "-d", destination.path])
    }

    static func gunzip(_ source: URL, to destination: URL) throws {
        let proc = Process()
        proc.executableURL = gunzip
        proc.arguments = ["-c", source.path]
        let out = FileHandle.standardOutput
        guard FileManager.default.createFile(atPath: destination.path, contents: nil) else {
            throw RestoreArchiveError.extractFailed("could not create \(destination.lastPathComponent)")
        }
        let handle = try FileHandle(forWritingTo: destination)
        defer { try? handle.close() }
        proc.standardOutput = handle
        let err = Pipe(); proc.standardError = err
        try proc.run()
        proc.waitUntilExit()
        _ = out
        guard proc.terminationStatus == 0 else {
            let msg = String(data: err.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "gunzip failed"
            throw RestoreArchiveError.extractFailed(msg)
        }
    }

    static func isGzip(_ file: URL) -> Bool {
        guard let handle = try? FileHandle(forReadingFrom: file) else { return false }
        defer { try? handle.close() }
        let magic = handle.readData(ofLength: 2)
        return magic.count == 2 && magic[magic.startIndex] == 0x1F && magic[magic.index(after: magic.startIndex)] == 0x8B
    }

    @discardableResult
    private static func run(_ executable: URL, _ arguments: [String]) throws -> String {
        let result = try ProcessRunner().run(ProcessRequest(
            executable: executable.path, arguments: arguments, environment: ["PATH": "/usr/bin:/bin"]
        ))
        guard result.succeeded else {
            throw RestoreArchiveError.extractFailed("\(executable.lastPathComponent) exit \(result.status): \(result.stderrText)")
        }
        return result.stdoutText
    }
}
