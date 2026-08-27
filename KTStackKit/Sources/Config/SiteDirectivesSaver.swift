import Foundation
import KTPlatformContracts
import KTStackCore

// Fail-closed cho front directives: ghi config ứng viên → nginx -t → reload, rollback nếu hỏng, chỉ
// persist sau khi validate qua. Mẫu NginxIncludeService, nhưng state là frontDirectives per-site nên
// regenerate từ candidate sites thay vì một file include. Tách struct để test bằng closure inject.
@MainActor
struct SiteDirectivesSaver {
    var generate: ([Site]) async throws -> Void
    var validate: () async -> NginxValidationResult
    var reload: () async throws -> Void
    var liveSites: () -> [Site]
    var persist: (Site, String?) -> Void

    func save(_ site: Site, _ text: String) async throws {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let previous = site.frontDirectives
        var candidate = site
        candidate.frontDirectives = trimmed.isEmpty ? nil : text
        let candidateSites = liveSites().map { $0.id == site.id ? candidate : $0 }

        try await generate(candidateSites)

        switch await validate() {
        case let .invalid(stderr):
            try? await generate(liveSites())
            throw NginxIncludeSaveError.rejected(stderr)
        case .couldNotRun:
            persist(site, candidate.frontDirectives) // file đã ghi, không revert
            throw NginxIncludeSaveError.couldNotValidate
        case .valid:
            break
        }

        persist(site, candidate.frontDirectives)
        do {
            try await reload()
        } catch {
            persist(site, previous)
            try? await generate(liveSites())
            try? await reload()
            throw NginxIncludeSaveError.reloadFailedReverted(error.localizedDescription)
        }
    }
}
