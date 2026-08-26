import Foundation
import KTPlatformContracts

@MainActor
final class PHPPoolEditorModel: ObservableObject {
    let version: String
    @Published var draft: PHPPoolSettings
    @Published private(set) var error: String?
    @Published private(set) var isSaving = false

    private let phpConfig: any PHPPoolEditing

    init(version: String, phpConfig: any PHPPoolEditing) {
        self.version = version
        self.phpConfig = phpConfig
        draft = phpConfig.defaultPoolSettings
    }

    var validationMessage: String? {
        draft.validate()
    }

    var canSave: Bool {
        validationMessage == nil && !isSaving
    }

    func load() {
        draft = (try? phpConfig.poolSettings(phpVersion: version)) ?? phpConfig.defaultPoolSettings
        error = nil
    }

    func reset() {
        draft = phpConfig.defaultPoolSettings
        error = nil
    }

    @discardableResult
    func save() async -> Bool {
        if let problem = validationMessage {
            error = problem
            return false
        }
        error = nil
        isSaving = true
        defer { isSaving = false }
        do {
            try await phpConfig.savePoolSettings(phpVersion: version, draft)
            return true
        } catch let saveError as PHPPoolSaveError {
            error = Self.message(for: saveError)
            return false
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    private static func message(for error: PHPPoolSaveError) -> String {
        switch error {
        case let .invalid(message):
            return message
        case let .rejected(stderr):
            return "php-fpm rejected the config and the previous settings were restored:\n\(stderr)"
        case let .restartFailedReverted(detail):
            return "Restart failed, previous settings restored:\n\(detail)"
        }
    }
}
