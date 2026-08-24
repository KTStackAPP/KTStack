import Foundation

// Capability Mailpit mà feature plugin (Mail) cần; platform conform trong KTStackKit.
public protocol MailpitProviding: AnyObject {
    nonisolated var mailpitAPIBaseURL: URL { get }
    @MainActor func startMailpit()
}
