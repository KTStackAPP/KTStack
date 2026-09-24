import Foundation
import KTStackCore

public struct RetiredEngineData: Sendable, Equatable {
    public let service: String
    public let version: String
    public let url: URL
    public let removedAt: Date
}

struct EngineDataVault: Sendable {
    static let removedDirectoryName = ".removed"
    let paths: AppSupportPaths

    func liveData(service: String, version: String) -> URL {
        paths.serviceData(service, version: version)
    }

    func removedRoot(service: String) -> URL {
        paths.serviceData(service).appendingPathComponent(Self.removedDirectoryName, isDirectory: true)
    }

    func retire(service: String, version: String, now: Date = Date()) throws -> URL? {
        let fm = FileManager.default
        let source = liveData(service: service, version: version)
        guard fm.fileExists(atPath: source.path) else { return nil }
        let root = removedRoot(service: service)
        try fm.createDirectory(at: root, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let base = "\(version)-\(RetiredDataName.stamp(now))"
        var destination = root.appendingPathComponent(base, isDirectory: true)
        var suffix = 2
        while fm.fileExists(atPath: destination.path) {
            destination = root.appendingPathComponent("\(base)-\(suffix)", isDirectory: true)
            suffix += 1
        }
        try fm.moveItem(at: source, to: destination)
        return destination
    }

    func retired(service: String) -> [RetiredEngineData] {
        let root = removedRoot(service: service)
        let names = (try? FileManager.default.contentsOfDirectory(atPath: root.path)) ?? []
        return names.compactMap { name in
            guard let parsed = RetiredDataName.parse(name) else { return nil }
            return RetiredEngineData(
                service: service,
                version: parsed.version,
                url: root.appendingPathComponent(name, isDirectory: true),
                removedAt: parsed.removedAt
            )
        }
        .sorted { $0.removedAt > $1.removedAt }
    }

    func restore(_ item: RetiredEngineData) throws {
        try requireContained(item)
        let fm = FileManager.default
        let destination = liveData(service: item.service, version: item.version)
        if fm.fileExists(atPath: destination.path) {
            let contents = try fm.contentsOfDirectory(atPath: destination.path)
            guard contents.isEmpty else {
                throw ServiceVersionError(
                    message: "\(item.version) already has data at \(destination.path). Move it aside before restoring."
                )
            }
            try fm.removeItem(at: destination)
        }
        try fm.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        try fm.moveItem(at: item.url, to: destination)
    }

    func trash(_ item: RetiredEngineData) throws {
        try requireContained(item)
        try FileManager.default.trashItem(at: item.url, resultingItemURL: nil)
    }

    static func size(of url: URL) -> Int64 {
        let keys: [URLResourceKey] = [.totalFileAllocatedSizeKey, .fileSizeKey, .isRegularFileKey]
        guard let walker = FileManager.default.enumerator(at: url, includingPropertiesForKeys: keys) else { return 0 }
        var total: Int64 = 0
        for case let file as URL in walker {
            guard let values = try? file.resourceValues(forKeys: Set(keys)), values.isRegularFile == true else { continue }
            total += Int64(values.totalFileAllocatedSize ?? values.fileSize ?? 0)
        }
        return total
    }

    private func requireContained(_ item: RetiredEngineData) throws {
        let parent = item.url.standardizedFileURL.deletingLastPathComponent().path
        guard parent == removedRoot(service: item.service).standardizedFileURL.path,
              RetiredDataName.parse(item.url.lastPathComponent) != nil
        else {
            throw ServiceVersionError(message: "\(item.url.path) is not kept engine data.")
        }
    }
}
