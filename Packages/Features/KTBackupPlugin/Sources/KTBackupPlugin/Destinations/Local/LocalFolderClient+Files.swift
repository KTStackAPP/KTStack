import Foundation

extension LocalFolderClient {
    func requireFolder() throws {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: folder.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw BackupDestinationError.unavailable(
                "The folder \(folder.path) isn't available. If it's on an external or network drive, make sure it's mounted."
            )
        }
    }

    func subdirectories(of base: URL) throws -> [URL] {
        try FileManager.default.contentsOfDirectory(
            at: base,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )
        .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
        .map { base.appendingPathComponent($0.lastPathComponent, isDirectory: true) }
        .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    }

    func checksumURL(for archive: URL) -> URL {
        archive.appendingPathExtension(Self.checksumExtension)
    }

    func object(at url: URL, planID: UUID) throws -> RemoteBackupObject {
        let checksum = (try? String(contentsOf: checksumURL(for: url), encoding: .utf8))?
            .split(separator: " ").first.map(String.init)
        return RemoteBackupObject(
            id: url.path,
            name: url.lastPathComponent,
            sizeBytes: try FileDigest.size(of: url),
            createdAt: BackupArchiveNaming.createdAt(url.lastPathComponent),
            planID: planID,
            sha256: checksum
        )
    }

    func freeSpace() -> Int64? {
        let values = try? folder.resourceValues(forKeys: [.volumeAvailableCapacityKey])
        return values?.volumeAvailableCapacity.map(Int64.init)
    }
}
