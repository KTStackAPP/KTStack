import Foundation
import KTPlatformContracts

extension ServiceManager: MailpitProviding {
    public nonisolated var mailpitAPIBaseURL: URL { MailpitController.apiBaseURL }

    // Start thuần, không toggle: nút chỉ hiện khi Mailpit unreachable, nhưng contract nói "start".
    public func startMailpit() {
        guard let svc = services[.mailpit] else { return }
        perform(.mailpit) { try await svc.start() }
    }
}
