import Foundation
import KTPlatformContracts

extension SitesViewModel {
    func startNodeProbing() {
        guard probeTask == nil else { return }
        probeTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refreshNodeRunning()
                try? await Task.sleep(nanoseconds: 2_500_000_000)
            }
        }
    }

    func stopNodeProbing() {
        probeTask?.cancel()
        probeTask = nil
    }

    func refreshNodeRunning() async {
        let targets = sites.filter { $0.kind == .node && $0.nodePort != nil }
        // Rebuild toàn bộ map: site rớt port/đổi loại/bị xóa phải mất trạng thái "live" cũ.
        let results = await withTaskGroup(of: (UUID, Bool).self) { group in
            for site in targets {
                group.addTask { [serverControl] in
                    (site.id, await serverControl.probeNode(port: site.nodePort!))
                }
            }
            var collected: [UUID: Bool] = [:]
            for await (id, running) in group { collected[id] = running }
            return collected
        }
        if nodeRunning != results { nodeRunning = results }
    }

    func refreshFrameworks() async {
        let targets = sites.filter { $0.kind == .php }
        guard !targets.isEmpty else { return }
        for site in targets {
            frameworks[site.id] = await PHPFrameworkCache.shared.framework(path: site.path, docroot: site.docroot)
        }
    }
}
