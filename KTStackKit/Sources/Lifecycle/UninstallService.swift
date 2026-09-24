import Combine
import Foundation
import KTStackCore

@MainActor
public final class UninstallService: ObservableObject {
    public enum State: Equatable { case idle, running, done, failed(String) }

    @Published public private(set) var state: State = .idle
    @Published public private(set) var log: [String] = []

    public var onFinished: (@MainActor (State) -> Void)?

    private let steps: UninstallSteps

    public convenience init(
        paths: AppSupportPaths,
        dns: DNSAutomationService,
        mkcertBinary: URL,
        quiesce: @escaping @MainActor @Sendable () async -> Void = {}
    ) {
        self.init(steps: .live(paths: paths, dns: dns, mkcertBinary: mkcertBinary, quiesce: quiesce))
    }

    public init(steps: UninstallSteps) {
        self.steps = steps
    }

    public func uninstall() {
        guard state != .running else { return }
        state = .running
        log = []
        Task { await run() }
    }

    func run() async {
        record("Starting uninstall…")
        await steps.quiesce()
        record("Stopped background polling and the CLI socket.")

        do {
            try await steps.disableDNS()
            record("Removed the DNS resolver.")
        } catch {
            record("DNS cleanup warning: \(error.localizedDescription)")
        }

        let work = steps
        let tail = await Task.detached(priority: .userInitiated) { () -> [String] in
            var notes: [String] = []
            do {
                try work.disableShell()
                notes.append("Removed shell PATH integration.")
            } catch {
                notes.append("Shell PATH cleanup warning: \(error.localizedDescription)")
            }
            do {
                try work.untrustCA()
                notes.append("Removed local CA trust.")
            } catch {
                notes.append("CA untrust warning: \(error.localizedDescription)")
            }
            work.bootoutAll()
            notes.append("Stopped all launchd services.")
            return notes
        }.value
        tail.forEach(record)

        let removal = await Task.detached(priority: .userInitiated) { () -> Result<URL?, Error> in
            Result { try work.removeDataRoot() }
        }.value
        var failure: String?
        switch removal {
        case let .success(trashed):
            record(trashed.map { "Moved app data, runtimes and databases to the Trash: \($0.path)" }
                ?? "No app data to remove.")
        case let .failure(error):
            failure = error.localizedDescription
            record("Data removal warning: \(error.localizedDescription)")
        }

        await Task.detached(priority: .userInitiated) { work.unregisterHelper() }.value
        record("Unregistered privileged helper (if installed).")

        if let left = work.resolverLeft() {
            record("Warning: \(left) still present — re-run, or remove it with sudo.")
            failure = failure ?? "DNS resolver not removed"
        }
        state = failure.map(State.failed) ?? .done
        onFinished?(state)
    }

    private func record(_ message: String) {
        log.append(message)
    }
}
