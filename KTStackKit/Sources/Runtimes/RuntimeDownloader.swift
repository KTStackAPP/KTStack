import Foundation
import KTStackCore

public struct RuntimeDownloader: Sendable {
    public struct Progress: Sendable {
        public let received: Int64
        public let total: Int64 // -1 when the server omits Content-Length
        public var fraction: Double {
            total > 0 ? min(1, Double(received) / Double(total)) : 0
        }
    }

    public struct ExtractError: LocalizedError {
        public let message: String
        public var errorDescription: String? {
            message
        }
    }

    static func requireHTTPS(_ url: URL) throws {
        guard url.scheme?.lowercased() == "https" else {
            throw ExtractError(message: "Refusing a non-HTTPS download URL (\(url.scheme ?? "none")).")
        }
    }

    static func isRedirectAllowed(to url: URL) -> Bool {
        url.scheme?.lowercased() == "https"
    }

    private let paths: AppSupportPaths
    public init(paths: AppSupportPaths) {
        self.paths = paths
    }

    @discardableResult
    public func install(
        _ release: RuntimeRelease,
        onProgress: @escaping @Sendable (Progress) -> Void
    ) async throws -> URL {
        try await installArchive(
            url: release.url, sha256: release.sha256,
            into: paths.runtimeDir(release.language.rawValue, release.version),
            markerRelPath: release.language.executableRelPath,
            onProgress: onProgress
        )
    }

    @discardableResult
    public func installArchive(
        url: URL,
        sha256: String,
        into dest: URL,
        markerRelPath: String,
        onProgress: @escaping @Sendable (Progress) -> Void
    ) async throws -> URL {
        try paths.ensureDirectoryTree()
        let coordinator = DownloadCoordinator { received, total in
            onProgress(Progress(received: received, total: total))
        }
        let archive = try await coordinator.download(url)
        defer { try? FileManager.default.removeItem(at: archive) }

        try Task.checkCancellation()
        try ChecksumVerifier.verify(archive, expected: sha256)
        let payload = try extract(archive)
        defer { try? FileManager.default.removeItem(at: payload.deletingLastPathComponent()) }

        try Task.checkCancellation()
        let fm = FileManager.default
        if fm.fileExists(atPath: dest.path) { try fm.removeItem(at: dest) }
        try fm.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
        try fm.moveItem(at: payload, to: dest) // atomic within the same volume
        Self.stripQuarantine(dest) // else an ad-hoc-signed php-fpm may be Gatekeeper-blocked

        guard fm.isExecutableFile(atPath: dest.appendingPathComponent(markerRelPath).path) else {
            try? fm.removeItem(at: dest)
            throw ExtractError(message: "Archive did not contain \(markerRelPath).")
        }
        return dest
    }

    @discardableResult
    public func installSharedObject(
        url: URL,
        sha256: String,
        soName: String,
        into modulesDir: URL,
        onProgress: @escaping @Sendable (Progress) -> Void
    ) async throws -> URL {
        try paths.ensureDirectoryTree()
        let coordinator = DownloadCoordinator { received, total in
            onProgress(Progress(received: received, total: total))
        }
        let archive = try await coordinator.download(url)
        defer { try? FileManager.default.removeItem(at: archive) }

        try Task.checkCancellation()
        try ChecksumVerifier.verify(archive, expected: sha256)
        let payload = try extract(archive) // single top-level dir, e.g. imagick/
        defer { try? FileManager.default.removeItem(at: payload.deletingLastPathComponent()) }

        let fm = FileManager.default
        let src = payload.appendingPathComponent(soName)
        guard fm.fileExists(atPath: src.path) else {
            throw ExtractError(message: "Archive did not contain \(soName).")
        }
        try Task.checkCancellation()
        try fm.createDirectory(
            at: modulesDir,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        let dest = modulesDir.appendingPathComponent(soName)
        let payloadItems = try fm.contentsOfDirectory(at: payload, includingPropertiesForKeys: nil)
        for item in payloadItems {
            let target = modulesDir.appendingPathComponent(item.lastPathComponent)
            if fm.fileExists(atPath: target.path) { try fm.removeItem(at: target) }
            try fm.moveItem(at: item, to: target)
            Self.stripQuarantine(target) // ad-hoc-signed .so + private dylibs are quarantined by URLSession
        }
        return dest
    }

    @discardableResult
    public func downloadVerifiedFile(
        url: URL,
        sha256: String,
        to dest: URL,
        onProgress: @escaping @Sendable (Progress) -> Void = { _ in }
    ) async throws -> URL {
        try Self.requireHTTPS(url)
        let coordinator = DownloadCoordinator { received, total in
            onProgress(Progress(received: received, total: total))
        }
        let temp = try await coordinator.download(url)
        defer { try? FileManager.default.removeItem(at: temp) }
        try Task.checkCancellation()
        try ChecksumVerifier.verify(temp, expected: sha256)
        let fm = FileManager.default
        try fm.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
        if fm.fileExists(atPath: dest.path) { try fm.removeItem(at: dest) }
        try fm.moveItem(at: temp, to: dest)
        Self.stripQuarantine(dest)
        return dest
    }

    private static func stripQuarantine(_ dir: URL) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/xattr")
        p.arguments = ["-dr", "com.apple.quarantine", dir.path]
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        try? p.run()
        p.waitUntilExit()
    }

    private func extract(_ archive: URL) throws -> URL {
        try Self.extract(archive, into: paths.runtimes)
    }

    static func extract(_ archive: URL, into root: URL) throws -> URL {
        let work = root.appendingPathComponent(".dl-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
        var extracted = false
        defer { if !extracted { try? FileManager.default.removeItem(at: work) } }
        let tar = try ProcessRunner().run("/usr/bin/tar", ["-xf", archive.path, "-C", work.path], timeout: 900)
        guard tar.succeeded else {
            throw ExtractError(message: "Extract failed: \(tar.stderrText.isEmpty ? "tar failed" : tar.stderrText)")
        }
        let entries = try FileManager.default.contentsOfDirectory(atPath: work.path)
            .filter { !$0.hasPrefix(".") }
        guard entries.count == 1 else {
            throw ExtractError(message: "Unexpected archive layout (\(entries.count) top-level entries).")
        }
        extracted = true
        return work.appendingPathComponent(entries[0], isDirectory: true)
    }
}
