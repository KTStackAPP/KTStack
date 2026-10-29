import Foundation
import KTStackCore

// Mọi thao tác file trên certs-custom/: stage → swapIn → commit, hoặc rollback về .bak.
public struct CustomCertificateStore: Sendable {
    let paths: AppSupportPaths

    public init(paths: AppSupportPaths) {
        self.paths = paths
    }

    private var fm: FileManager { .default }

    private func live(_ id: String) -> URL { paths.siteCustomCertDir(id) }
    private func backup(_ id: String) -> URL { paths.customCertsDir.appendingPathComponent("\(id).bak", isDirectory: true) }
    private func staging(_ id: String) -> URL { paths.customCertsDir.appendingPathComponent("\(id).staging", isDirectory: true) }

    func stage(id: String, certPEM: Data, keyPEM: Data) throws -> URL {
        try fm.createDirectory(at: paths.customCertsDir, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        let dir = staging(id)
        if fm.fileExists(atPath: dir.path) { try fm.removeItem(at: dir) }
        try fm.createDirectory(at: dir, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        let cert = dir.appendingPathComponent("fullchain.pem")
        let key = dir.appendingPathComponent("privkey.pem")
        try certPEM.write(to: cert)
        try fm.setAttributes([.posixPermissions: 0o644], ofItemAtPath: cert.path)
        // Tạo file rỗng 0600 trước rồi mới ghi key để key không bao giờ nằm trên đĩa với mode rộng hơn.
        guard fm.createFile(atPath: key.path, contents: nil, attributes: [.posixPermissions: 0o600]) else {
            throw CocoaError(.fileWriteUnknown, userInfo: [NSFilePathErrorKey: key.path])
        }
        let handle = try FileHandle(forWritingTo: key)
        defer { try? handle.close() }
        try handle.write(contentsOf: keyPEM)
        return dir
    }

    func swapIn(id: String, staged: URL) throws {
        if fm.fileExists(atPath: live(id).path) {
            if fm.fileExists(atPath: backup(id).path) { try fm.removeItem(at: backup(id)) }
            try fm.moveItem(at: live(id), to: backup(id))
        }
        try fm.moveItem(at: staged, to: live(id))
    }

    func rollback(id: String) {
        try? fm.removeItem(at: live(id))
        if fm.fileExists(atPath: backup(id).path) {
            try? fm.moveItem(at: backup(id), to: live(id))
        }
    }

    func commit(id: String) {
        try? fm.removeItem(at: backup(id))
    }

    public func remove(id: String) {
        for dir in [live(id), backup(id), staging(id)] {
            try? fm.removeItem(at: dir)
        }
    }

    public func verifyCoverage(for site: Site, now: Date = Date()) throws {
        let id = site.id.uuidString
        let certPEM = try Data(contentsOf: paths.siteCustomCert(id))
        let keyPEM = try Data(contentsOf: paths.siteCustomKey(id))
        let names = try CustomCertificateInspector().inspect(certPEM: certPEM, keyPEM: keyPEM, now: now).names
        let missing = CustomCertificateInspector.uncovered(site.serverNames, by: names)
        if !missing.isEmpty { throw CustomCertificateError.namesNotCovered(missing) }
    }

    public func pruneOrphans(keeping ids: Set<String>) {
        guard let entries = try? fm.contentsOfDirectory(at: paths.customCertsDir, includingPropertiesForKeys: nil) else { return }
        for entry in entries where !entry.lastPathComponent.hasPrefix(".") {
            var name = entry.lastPathComponent
            for suffix in [".bak", ".staging"] where name.hasSuffix(suffix) {
                name.removeLast(suffix.count)
            }
            if !ids.contains(name) { try? fm.removeItem(at: entry) }
        }
    }
}
