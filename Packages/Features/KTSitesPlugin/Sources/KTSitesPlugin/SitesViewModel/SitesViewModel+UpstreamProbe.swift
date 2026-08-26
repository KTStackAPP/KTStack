import Foundation
import KTPlatformContracts
import KTStackCore

extension SitesViewModel {
    func startUpstreamProbing() {
        guard probeTask == nil else { return }
        probeTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refreshUpstreamRunning()
                try? await Task.sleep(nanoseconds: 2_500_000_000)
            }
        }
    }

    func stopUpstreamProbing() {
        probeTask?.cancel()
        probeTask = nil
    }

    func refreshUpstreamRunning() async {
        // Rebuild toàn bộ map: site rớt port/đổi loại/bị xóa phải mất trạng thái "live" cũ.
        let targets: [(id: UUID, host: String, port: Int)] = sites.compactMap { site in
            switch site.kind {
            case .node:
                guard let port = site.nodePort else { return nil }
                return (site.id, "127.0.0.1", port)
            case .proxy:
                guard let raw = site.proxyTarget,
                      case let .success(target) = ProxyTarget.parse(raw) else { return nil }
                return (site.id, target.host, target.port)
            default:
                return nil
            }
        }
        let results = await withTaskGroup(of: (UUID, Bool).self) { group in
            for target in targets {
                group.addTask { [serverControl] in
                    (target.id, await serverControl.probeUpstream(host: target.host, port: target.port))
                }
            }
            var collected: [UUID: Bool] = [:]
            for await (id, running) in group { collected[id] = running }
            return collected
        }
        if upstreamRunning != results { upstreamRunning = results }
    }

    func refreshFrameworks() async {
        let targets = sites.filter { $0.kind == .php }
        guard !targets.isEmpty else { return }
        for site in targets {
            frameworks[site.id] = await PHPFrameworkCache.shared.framework(path: site.path, docroot: site.docroot)
        }
    }
}
