import Foundation
import KTPlatformContracts
import SwiftUI

@MainActor
final class NginxIncludeEditorModel: ObservableObject {
    @Published var text = ""
    @Published private(set) var isBusy = false
    @Published private(set) var errorMessage: String?

    private let nginxInclude: any NginxIncludeEditing

    init(nginxInclude: any NginxIncludeEditing) {
        self.nginxInclude = nginxInclude
    }

    func load() {
        text = (try? nginxInclude.readInclude()) ?? nginxInclude.defaultInclude
        errorMessage = nil
    }

    func reset() {
        text = nginxInclude.defaultInclude
        errorMessage = nil
    }

    func save() async -> Bool {
        isBusy = true
        errorMessage = nil
        defer { isBusy = false }
        do {
            try await nginxInclude.saveInclude(text)
            return true
        } catch let error as NginxIncludeSaveError {
            errorMessage = Self.message(for: error)
            return false
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    private static func message(for error: NginxIncludeSaveError) -> String {
        switch error {
        case let .rejected(stderr):
            "nginx rejected the config (not applied):\n\(stderr)\n\n"
                + "If the path above is not nginx-extra.conf, the problem is in a generated vhost, not your edit."
        case .couldNotValidate:
            "Could not validate: nginx is not runnable. The file was written but could not be confirmed safe."
        case let .reloadFailedReverted(detail):
            "Config valid but reload failed; reverted to the previous nginx-extra.conf.\n\(detail)"
        }
    }
}
