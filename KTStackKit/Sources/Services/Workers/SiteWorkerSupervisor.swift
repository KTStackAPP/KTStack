import Foundation
import KTStackCore

enum SiteWorkerStartError: LocalizedError {
    case notLoaded

    var errorDescription: String? {
        "the job was not loaded after bootstrap"
    }
}

public struct SiteWorkerSupervisor: Sendable {
    static let missingSupervisorMessage =
        "KTStack's kt helper is missing from the app bundle, so workers can't run. Reinstall KTStack."
    static let bootstrapAttempts = 2
    static let bootstrapRetryDelay: TimeInterval = 0.5

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
        let desired = Self.desired(sites)
        guard let launch = launch() else {
            loaded.forEach(tearDown)
            for (site, worker) in desired {
                recordFailure(label(site: site, worker: worker), Self.missingSupervisorMessage)
            }
            return
        }
        var specs: [String: LaunchAgentSpec] = [:]
        for (site, worker) in desired {
            guard let spec = launch.spec(site: site, worker: worker, phpVersion: effectivePHPVersion(site.phpVersion)) else {
                recordFailure(label(site: site, worker: worker), "The command of \(worker.name) can't be read. Edit it in Site Settings.")
                continue
            }
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
        guard agents.isLoadedNow(label) else {
            startFresh(site: site, worker: worker)
            return
        }
        try? FileManager.default.removeItem(at: paths.siteWorkerStatus(label))
        do {
            try agents.kickstart(label)
        } catch {
            recordFailure(label, "Restart failed: \(error.localizedDescription)")
        }
    }

    private func startFresh(site: Site, worker: SiteWorker) {
        guard worker.enabled, site.supportsWorkers else { return }
        let label = self.label(site: site, worker: worker)
        guard let launch = launch() else { return recordFailure(label, Self.missingSupervisorMessage) }
        guard let spec = launch.spec(site: site, worker: worker, phpVersion: effectivePHPVersion(site.phpVersion)) else {
            return recordFailure(label, "The command of \(worker.name) can't be read. Edit it in Site Settings.")
        }
        start(spec, alreadyLoaded: false)
    }

    private func start(_ spec: LaunchAgentSpec, alreadyLoaded: Bool) {
        let fingerprint = paths.siteWorkerSpec(spec.label)
        let data = Self.fingerprint(of: spec)
        if alreadyLoaded, (try? Data(contentsOf: fingerprint)) == data { return }
        try? FileManager.default.removeItem(at: fingerprint)
        do {
            if alreadyLoaded { try agents.bootout(spec.label) }
            try? FileManager.default.removeItem(at: paths.siteWorkerStatus(spec.label))
            try bootstrapVerified(spec)
            try FileManager.default.createDirectory(at: paths.siteWorkerStatusDir, withIntermediateDirectories: true)
            try data.write(to: fingerprint, options: .atomic)
        } catch {
            recordFailure(spec.label, "launchd did not start the worker: \(error.localizedDescription)")
        }
    }

    private func bootstrapVerified(_ spec: LaunchAgentSpec) throws {
        for attempt in 0..<Self.bootstrapAttempts {
            if attempt > 0 { Thread.sleep(forTimeInterval: Self.bootstrapRetryDelay) }
            try agents.bootstrap(spec)
            if agents.isLoadedNow(spec.label) { return }
        }
        throw SiteWorkerStartError.notLoaded
    }

    func recordFailure(_ label: String, _ message: String) {
        ServiceDiagnostics(paths: paths).log(.error, "site worker \(label): \(message)")
        WorkerStatus(state: .failedToStart, message: message).write(to: paths.siteWorkerStatus(label))
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
