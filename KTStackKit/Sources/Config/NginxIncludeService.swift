import Foundation
import KTPlatformContracts
import KTStackCore

// Gom orchestration ghi nginx include: write(.bak) → validate → reload → rollback (mẫu PHPConfigService).
public struct NginxIncludeService: NginxIncludeEditing, Sendable {
    private let store: NginxUserIncludeStore
    private let validate: @Sendable () async -> NginxValidationResult
    private let reload: @Sendable () async throws -> Void

    public init(
        paths: AppSupportPaths = AppSupportPaths(),
        validate: @escaping @Sendable () async -> NginxValidationResult,
        reload: @escaping @Sendable () async throws -> Void
    ) {
        store = NginxUserIncludeStore(paths: paths)
        self.validate = validate
        self.reload = reload
    }

    public var defaultInclude: String { NginxUserIncludeTemplate.default }

    public func readInclude() throws -> String {
        try store.read()
    }

    public func saveInclude(_ contents: String) async throws {
        try store.write(contents: contents)
        switch await validate() {
        case .invalid(let stderr):
            try? store.restoreBackup()
            throw NginxIncludeSaveError.rejected(stderr)
        case .couldNotRun:
            // File đã ghi, không revert (hành vi hôm nay): nginx không chạy được để xác nhận.
            throw NginxIncludeSaveError.couldNotValidate
        case .valid:
            break
        }
        do {
            try await reload()
        } catch {
            try? store.restoreBackup()
            throw NginxIncludeSaveError.reloadFailedReverted(error.localizedDescription)
        }
    }
}
