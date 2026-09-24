import Foundation

public enum StagedBinaryInstaller {
    public struct Rejected: LocalizedError {
        public let path: String

        public var errorDescription: String? {
            "Refused to install \(path): the binary failed its code-signature check."
        }
    }

    public static func install(_ data: Data, to destination: URL, mode: Int, verify: (URL) -> Bool) throws {
        let fileManager = FileManager.default
        let directory = destination.deletingLastPathComponent()
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let staged = directory.appendingPathComponent(".\(destination.lastPathComponent).staged-\(UUID().uuidString)")
        try data.write(to: staged, options: .withoutOverwriting)
        do {
            try fileManager.setAttributes([.posixPermissions: mode], ofItemAtPath: staged.path)
            guard verify(staged) else { throw Rejected(path: destination.path) }
            guard rename(staged.path, destination.path) == 0 else {
                throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
            }
        } catch {
            try? fileManager.removeItem(at: staged)
            throw error
        }
    }
}
