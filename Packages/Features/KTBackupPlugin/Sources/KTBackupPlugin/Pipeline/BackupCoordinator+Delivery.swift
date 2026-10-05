import Foundation

extension BackupCoordinator {
    func deliver(_ staged: StagedBackup, plan: BackupPlan, run: inout BackupRun, onPhase: @escaping PhaseHandler) async throws {
        defer { try? FileManager.default.removeItem(at: staged.archiveURL) }
        run.items = staged.items
        run.archiveName = staged.fileName
        run.sizeBytes = staged.sizeBytes
        run.sha256 = staged.sha256
        let destination = store.snapshot.destination(plan.destinationID)
        if plan.destinationID != nil, destination == nil {
            throw BackupDestinationError.notConfigured("the destination for this plan was removed.")
        }
        let client = try destinations.client(for: destination)
        let request = BackupUploadRequest(
            fileURL: staged.archiveURL,
            fileName: staged.fileName,
            planFolderName: BackupArchiveNaming.folderName(for: plan),
            planID: plan.id,
            sha256: staged.sha256,
            sizeBytes: staged.sizeBytes
        )
        let planID = plan.id
        let uploaded = try await client.upload(request) { onPhase(planID, .uploading($0)) }
        run.remoteID = uploaded.id
        onPhase(plan.id, .cleaningUp)
        run.warnings += await BackupRetention.prune(client, planID: plan.id, keepLast: plan.keepLast)
        if plan.keepLocalCopy, destination != nil {
            run.warnings += await keepLocalCopy(request, keepLast: plan.keepLast)
        }
        run.status = BackupRun.status(for: run.items)
        if run.status == .partial {
            run.message = "Some items couldn't be backed up."
        }
    }

    private func keepLocalCopy(_ request: BackupUploadRequest, keepLast: Int) async -> [String] {
        let local = destinations.localArchivesClient()
        do {
            _ = try await local.upload(request) { _ in }
        } catch {
            return ["Couldn't keep a local copy: \(error.localizedDescription)"]
        }
        return await BackupRetention.prune(local, planID: request.planID, keepLast: keepLast)
    }
}
