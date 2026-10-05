import Foundation
import KTStackCore

public struct SiteWorkerSupervisor: Sendable {
    let paths: AppSupportPaths
    let agents: any LaunchAgentManaging
    let listLoaded: @Sendable (String) -> [String]
    let supervisorExecutable: @Sendable () -> URL?
    let effectivePHPVersion: @Sendable (String) -> String
    let parentPID: pid_t

    init(
        paths: AppSupportPaths,
        agents: any LaunchAgentManaging,
        listLoaded: @escaping @Sendable (String) -> [String],
        supervisorExecutable: @escaping @Sendable () -> URL?,
        effectivePHPVersion: @escaping @Sendable (String) -> String,
        parentPID: pid_t = getpid()
    ) {
        self.paths = paths
        self.agents = agents
        self.listLoaded = listLoaded
        self.supervisorExecutable = supervisorExecutable
        self.effectivePHPVersion = effectivePHPVersion
        self.parentPID = parentPID
    }

    public init(paths: AppSupportPaths, agents: LaunchAgentManager) {
        self.init(
            paths: paths,
            agents: agents,
            listLoaded: { agents.loadedLabels(withPrefix: $0) },
            supervisorExecutable: { Self.bundledSupervisor() },
            effectivePHPVersion: { SiteConfigGenerator(paths: paths).effectivePHPVersion($0) }
        )
    }

    static func bundledSupervisor() -> URL? {
        guard let url = Bundle.main.url(forAuxiliaryExecutable: "kt"),
              FileManager.default.isExecutableFile(atPath: url.path) else { return nil }
        return url
    }

    static func desired(_ sites: [Site]) -> [(site: Site, worker: SiteWorker)] {
        sites.filter(\.supportsWorkers).flatMap { site in
            site.workers.filter(\.enabled).map { (site: site, worker: $0) }
        }
    }

    func launch() -> SiteWorkerLaunch? {
        supervisorExecutable().map { SiteWorkerLaunch(paths: paths, supervisorExecutable: $0, parentPID: parentPID) }
    }

    func loadedLabels() -> [String] {
        listLoaded(AppSupportPaths.siteWorkerLabelPrefix)
    }

    func label(site: Site, worker: SiteWorker) -> String {
        paths.siteWorkerLabel(siteID: site.id.uuidString, workerID: worker.id.uuidString)
    }

    func statusURL(_ label: String) -> URL {
        paths.siteWorkerStatus(label)
    }

    public func reconcile(sites: [Site]) {
        let loaded = Set(loadedLabels())
        guard let launch = launch() else {
            loaded.forEach(tearDown)
            if !Self.desired(sites).isEmpty {
                ServiceDiagnostics(paths: paths).log(.error, "site workers: the kt supervisor is missing from the app bundle")
            }
            return
        }
        var specs: [String: LaunchAgentSpec] = [:]
        for (site, worker) in Self.desired(sites) {
            guard let spec = launch.spec(site: site, worker: worker, phpVersion: effectivePHPVersion(site.phpVersion)) else { continue }
            specs[spec.label] = spec
        }
        for label in loaded where specs[label] == nil {
            tearDown(label)
        }
        for spec in specs.values.sorted(by: { $0.label < $1.label }) {
            start(spec, alreadyLoaded: loaded.contains(spec.label))
        }
    }

    public func stopAll() {
        loadedLabels().forEach(tearDown)
    }

    public func restart(site: Site, worker: SiteWorker) {
        let label = self.label(site: site, worker: worker)
        guard agents.isLoadedNow(label) else { return }
        try? FileManager.default.removeItem(at: paths.siteWorkerStatus(label))
        do {
            try agents.kickstart(label)
        } catch {
            ServiceDiagnostics(paths: paths).log(.error, "site worker \(worker.name) restart failed: \(error.localizedDescription)")
        }
    }

    private func start(_ spec: LaunchAgentSpec, alreadyLoaded: Bool) {
        let fingerprint = paths.siteWorkerSpec(spec.label)
        let data = Self.fingerprint(of: spec)
        if alreadyLoaded, (try? Data(contentsOf: fingerprint)) == data { return }
        do {
            if alreadyLoaded { try agents.bootout(spec.label) }
            try? FileManager.default.removeItem(at: paths.siteWorkerStatus(spec.label))
            try agents.bootstrap(spec)
            try FileManager.default.createDirectory(at: paths.siteWorkerStatusDir, withIntermediateDirectories: true)
            try data.write(to: fingerprint, options: .atomic)
        } catch {
            ServiceDiagnostics(paths: paths).log(.error, "site worker \(spec.label) did not start: \(error.localizedDescription)")
        }
    }

    private func tearDown(_ label: String) {
        try? agents.bootout(label)
        for url in [paths.launchAgentPlist(label), paths.siteWorkerStatus(label), paths.siteWorkerSpec(label)] {
            try? FileManager.default.removeItem(at: url)
        }
    }

    static func fingerprint(of spec: LaunchAgentSpec) -> Data {
        let fields: [String: Any] = [
            "arguments": spec.programArguments,
            "environment": spec.environment,
            "workingDirectory": spec.workingDirectory ?? "",
            "log": spec.stdoutPath ?? "",
        ]
        return (try? JSONSerialization.data(withJSONObject: fields, options: [.sortedKeys])) ?? Data()
    }
}
