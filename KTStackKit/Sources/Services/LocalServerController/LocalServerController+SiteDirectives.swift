import Foundation
import KTPlatformContracts
import KTStackCore

public extension LocalServerController {
    // Không đi qua reconcile() vì cần kết quả nginx -t trước khi persist; SiteDirectivesSaver giữ trình
    // tự fail-closed. isBusy chặn reconcile song song từ registry hook; config trên đĩa đã đúng lúc thoát
    // nên bỏ pendingReconcile.
    func saveFrontDirectives(_ site: Site, _ text: String) async throws {
        guard !isBusy else { throw SiteRegistry.RegistryError.serverBusy }
        let generator = self.generator
        let port = httpPort
        let saver = SiteDirectivesSaver(
            generate: { sites in
                try await Task.detached(priority: .userInitiated) {
                    _ = try generator.generate(sites: sites, port: port)
                }.value
            },
            validate: { await self.validateNginxConfig() },
            reload: { try await self.reloadNginxConfig() },
            liveSites: { self.registry.sites },
            persist: { self.registry.setFrontDirectives($0, $1) }
        )

        isBusy = true
        defer { isBusy = false; pendingReconcile = false }
        try await saver.save(site, text)
    }
}
