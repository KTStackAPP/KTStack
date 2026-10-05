import Foundation
import KTPlatformContracts

public actor BackupPlanRunner {
    private let builder: BackupStagingBuilder
    private let environment: any BackupRuntimeEnvironment
    private let paths: BackupPaths
    private var active = Set<UUID>()

    public init(databases: any ScheduledDatabaseBackupProviding, environment: any BackupRuntimeEnvironment,
                paths: BackupPaths, settings: SettingsSnapshotWriter) {
        builder = BackupStagingBuilder(databases: databases, settings: settings)
        self.environment = environment
        self.paths = paths
    }

    public func isRunning(_ planID: UUID) -> Bool {
        active.contains(planID)
    }

    public func stage(_ plan: BackupPlan, at date: Date) async throws -> StageOutcome {
        guard active.insert(plan.id).inserted else { throw BackupPipelineError.alreadyRunning }
        defer { active.remove(plan.id) }
        guard plan.hasContent else { return .skipped(.nothingSelected) }
        let running = await environment.runningEngines()
        if !plan.databases.isEmpty, !plan.includeSites, !plan.includeSettings,
           !plan.databases.contains(where: { DatabaseEngine(rawValue: $0.engine).map(running.contains) ?? false }) {
            return .skipped(.engineStopped)
        }
        let sites = plan.includeSites ? await environment.siteFolders(plan.siteIDs) : []
        return .staged(try await build(plan, date: date, running: running, sites: sites))
    }

    private func build(_ plan: BackupPlan, date: Date, running: Set<DatabaseEngine>,
                       sites: [BackupSiteFolder]) async throws -> StagedBackup {
        try paths.ensureDirectories()
        let fileName = BackupArchiveNaming.fileName(for: plan, at: date)
        let workRoot = paths.staging.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let content = workRoot.appendingPathComponent((fileName as NSString).deletingPathExtension, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: workRoot) }
        try FileManager.default.createDirectory(at: content, withIntermediateDirectories: true)
        var manifest = BackupArchiveManifest(planID: plan.id, planName: plan.name, createdAt: date)
        var items = await builder.stageDatabases(plan.databases, running: running, into: content, manifest: &manifest)
        items += builder.stageSites(sites, missing: plan.siteIDs, excludes: plan.siteExcludes, into: content, manifest: &manifest)
        if plan.includeSettings {
            items.append(builder.stageSettings(into: content, manifest: &manifest))
        }
        guard items.contains(where: \.succeeded) else {
            let detail = items.compactMap(\.message).joined(separator: "; ")
            throw BackupPipelineError.nothingBackedUp(detail.isEmpty ? "no items" : detail)
        }
        try manifest.write(in: content)
        let archive = paths.staging.appendingPathComponent(fileName)
        try? FileManager.default.removeItem(at: archive)
        try ArchiveTool.zip(directory: content, to: archive)
        return StagedBackup(
            archiveURL: archive,
            fileName: fileName,
            sizeBytes: try FileDigest.size(of: archive),
            sha256: try FileDigest.sha256Hex(of: archive),
            items: items
        )
    }
}
