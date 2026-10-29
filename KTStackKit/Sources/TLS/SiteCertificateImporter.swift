import Foundation
import KTStackCore

// Import fail-closed: copy cặp PEM → render → nginx -t → persist → reload; hỏng ở đâu cũng trả file
// và record về như cũ. Chặt hơn directives: nginx không chạy được thì cũng revert.
@MainActor
struct SiteCertificateImporter {
    var store: CustomCertificateStore
    var generate: ([Site]) async throws -> Void
    var validate: () async -> NginxValidationResult
    var reload: () async throws -> Void
    var liveSites: () -> [Site]
    var persist: (Site, SiteCustomCertificate?, Bool) -> Void
    var now: () -> Date = Date.init

    func importCertificate(_ site: Site, certPath: String, keyPath: String) async throws {
        let certPEM = try Data(contentsOf: URL(fileURLWithPath: certPath))
        let keyPEM = try Data(contentsOf: URL(fileURLWithPath: keyPath))
        let info = try CustomCertificateInspector().inspect(certPEM: certPEM, keyPEM: keyPEM, now: now())
        let cert = SiteCustomCertificate(sourceCertPath: certPath, sourceKeyPath: keyPath, notAfter: info.notAfter, names: info.names)
        let missing = CustomCertificateInspector.uncovered(site.serverNames, by: info.names)
        if !missing.isEmpty { throw CustomCertificateError.namesNotCovered(missing) }

        let id = site.id.uuidString
        let staged = try store.stage(id: id, certPEM: certPEM, keyPEM: keyPEM)
        try store.swapIn(id: id, staged: staged)

        var candidate = site
        candidate.customCertificate = cert
        candidate.secure = true
        do {
            try await generate(liveSites().map { $0.id == site.id ? candidate : $0 })
        } catch {
            await revertFiles(id)
            throw error
        }

        switch await validate() {
        case let .invalid(stderr):
            await revertFiles(id)
            throw CustomCertificateError.rejected(stderr)
        case .couldNotRun:
            await revertFiles(id)
            throw CustomCertificateError.couldNotValidate
        case .valid:
            break
        }

        persist(site, cert, true)
        do {
            try await reload()
        } catch {
            persist(site, site.customCertificate, site.secure)
            await revertFiles(id)
            try? await reload()
            throw CustomCertificateError.reloadFailedReverted(error.localizedDescription)
        }
        store.commit(id: id)
    }

    // HTTPS tắt theo; bật lại từ toggle sẽ mint cert local.
    func removeCertificate(_ site: Site) async throws {
        persist(site, nil, false)
        try await generate(liveSites())
        // Vhost đã hết trỏ tới cặp này và nginx giữ bản cũ trong bộ nhớ, nên reload hỏng vẫn xoá được.
        defer { store.remove(id: site.id.uuidString) }
        try await reload()
    }

    private func revertFiles(_ id: String) async {
        store.rollback(id: id)
        try? await generate(liveSites())
    }
}
