import Foundation
import KTPlatformContracts

@MainActor
final class RestoreBackupModel: ObservableObject {
    enum Stage: Equatable { case idle, ready, running, success, failed }

    let site: SiteSummary

    @Published private(set) var backupFile: URL?
    @Published private(set) var kind: WordPressBackupKind?
    @Published var phpVersion: String
    @Published var secure: Bool
    @Published var repairEncoding = true
    @Published var trusted = false
    @Published private(set) var stage: Stage = .idle
    @Published private(set) var phase: RestorePhase?
    @Published private(set) var message = ""
    @Published private(set) var warnings: [String] = []
    @Published var error: String?

    private let restoring: any WordPressRestoring
    private var task: Task<Void, Never>?

    init(site: SiteSummary, restoring: any WordPressRestoring) {
        self.site = site
        self.restoring = restoring
        phpVersion = site.phpVersion
        secure = site.secure
    }

    var canRestore: Bool {
        backupFile != nil && kind != nil && trusted && stage != .running
    }

    func selectFile(_ url: URL, installed: [String]) {
        do {
            kind = try restoring.inspectBackup(url)
            backupFile = url
            if !installed.contains(phpVersion) { phpVersion = installed.first ?? site.phpVersion }
            error = nil
            stage = .ready
        } catch {
            self.error = error.localizedDescription
            kind = nil
            backupFile = nil
            stage = .idle
        }
    }

    func restore() {
        guard let backupFile, canRestore else { return }
        stage = .running
        error = nil
        warnings = []
        phase = .detecting
        message = ""

        let request = RestoreRequest(
            backupFile: backupFile,
            siteFolder: URL(fileURLWithPath: site.path, isDirectory: true),
            siteDomain: site.domain,
            phpVersion: phpVersion,
            secure: secure,
            repairEncoding: repairEncoding
        )

        task = Task {
            do {
                let outcome = try await restoring.restore(request, into: site.id) { event in
                    Task { @MainActor in
                        self.phase = event.phase
                        self.message = event.message
                    }
                }
                self.warnings = outcome.warnings
                self.stage = .success
            } catch is CancellationError {
                self.error = "Restore cancelled."
                self.stage = .failed
            } catch {
                self.error = error.localizedDescription
                self.stage = .failed
            }
        }
    }

    func cancel() {
        task?.cancel()
    }
}
