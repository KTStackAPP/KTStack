import Combine
import Foundation
#if canImport(ServiceManagement)
    import ServiceManagement
#endif

@MainActor
public final class DNSAutomationService: ObservableObject {
    public enum Status: Equatable, Sendable {
        case unknown
        case disabled // no /etc/resolver/test
        case enabled // resolver present
        case conflict(String) // a foreign process holds :53
    }

    @Published public private(set) var status: Status = .unknown
    @Published public private(set) var isBusy = false
    @Published public private(set) var lastError: String?

    public let usesHelper = HelperIdentity.hasSigningIdentity

    public let tld: String

    private nonisolated let fallback: SudoFallbackInstaller
    private nonisolated let port53 = Port53ConflictDetector()
    private nonisolated let helper = HelperConnection()

    public init(bundledDnsmasq: URL, tld: String = AppPreferences.defaultTLD) {
        self.tld = tld
        fallback = SudoFallbackInstaller(bundledDnsmasq: bundledDnsmasq, tld: tld)
        refresh()
    }

    private enum Op { case enable, disable, reset }

    // The resolver-file check is instant; the :53 conflict probe shells out to lsof, so run it off
    // the main actor and fold the result in when it returns, to avoid a menu-bar UI hitch.
    public func refresh() {
        let present = FileManager.default.fileExists(atPath: DNSConstants.resolverPath(for: tld))
        status = present ? .enabled : .disabled
        let port53 = port53
        Task.detached(priority: .utility) {
            guard let conflict = port53.check() else { return }
            await MainActor.run { self.status = .conflict(conflict.process) }
        }
    }

    public var isEnabled: Bool {
        status == .enabled
    }

    // True when the signed build registered the privileged helper but the user hasn't allowed it in
    // System Settings > Login Items yet, so DNS can't reach the helper. Drives the approval banner.
    public var helperNeedsApproval: Bool {
        guard usesHelper else { return false }
        #if canImport(ServiceManagement)
            if #available(macOS 13, *) {
                return SMAppService.daemon(plistName: HelperIdentity.daemonPlistName).status == .requiresApproval
            }
        #endif
        return false
    }

    public func enable() {
        perform(.enable)
    }

    public func disable() {
        perform(.disable)
    }

    public func reset() {
        perform(.reset)
    }

    public func changeTLD(to newTLD: String, completion: @escaping @MainActor (Result<Void, Error>) -> Void) {
        guard !isBusy else {
            completion(.failure(NSError(
                domain: "KTStack",
                code: -3,
                userInfo: [NSLocalizedDescriptionKey: "Another DNS operation is in progress."]
            )))
            return
        }
        guard newTLD != tld else { completion(.success(())); return }
        isBusy = true; lastError = nil
        let usesHelper = usesHelper, fallback = fallback, helper = helper, old = tld, port53 = port53
        Task.detached(priority: .userInitiated) {
            var failure: Error?
            do {
                if let conflict = port53.check() {
                    await MainActor.run { self.lastError = conflict.message; self.status = .conflict(conflict.process) }
                    throw NSError(domain: "KTStack", code: -4,
                                  userInfo: [NSLocalizedDescriptionKey: conflict.message])
                }
                if usesHelper { try await Self.viaHelperSetTLD(helper, old: old, new: newTLD) }
                else { try fallback.runSetTLDWithAdminPrivileges(old: old, new: newTLD) }
            } catch {
                failure = error
            }
            await MainActor.run {
                self.isBusy = false
                if let failure { self.lastError = failure.localizedDescription; completion(.failure(failure)) }
                else { self.refresh(); completion(.success(())) }
            }
        }
    }

    // Fire-and-forget for the UI buttons; swallows the busy/failure throw (surfaced via lastError).
    private func perform(_ op: Op) {
        Task { try? await runOp(op) }
    }

    // Awaitable variants so service supervision (DnsmasqProxyService) sees the real outcome instead
    // of a start() that reports success before the async enable has even run.
    public func enableAndWait() async throws { try await runOp(.enable) }
    public func disableAndWait() async throws { try await runOp(.disable) }
    public func resetAndWait() async throws { try await runOp(.reset) }

    private func runOp(_ op: Op) async throws {
        guard !isBusy else {
            throw NSError(domain: "KTStack", code: -3,
                          userInfo: [NSLocalizedDescriptionKey: "Another DNS operation is in progress."])
        }
        isBusy = true; lastError = nil
        defer { isBusy = false }
        do {
            if op != .disable, let conflict = await Self.conflict(using: port53) {
                status = .conflict(conflict.process); lastError = conflict.message
                throw NSError(domain: "KTStack", code: -4,
                              userInfo: [NSLocalizedDescriptionKey: conflict.message])
            }
            if usesHelper { try await Self.viaHelper(helper, op, tld: tld) }
            else { try await Self.viaFallbackOffMain(fallback, op) }
            refresh()
        } catch {
            lastError = error.localizedDescription
            refresh()
            throw error
        }
    }

    private nonisolated static func conflict(using port53: Port53ConflictDetector) async -> Port53ConflictDetector.Conflict? {
        await Task.detached(priority: .utility) { port53.check() }.value
    }

    private nonisolated static func viaFallbackOffMain(_ f: SudoFallbackInstaller, _ op: Op) async throws {
        try await Task.detached(priority: .userInitiated) { try viaFallback(f, op) }.value
    }

    private nonisolated static func viaFallback(_ f: SudoFallbackInstaller, _ op: Op) throws {
        switch op {
        case .enable: try f.runInstallWithAdminPrivileges()
        case .disable: try f.runUninstallWithAdminPrivileges()
        case .reset: try f.runResetWithAdminPrivileges()
        }
    }

    private nonisolated static func viaHelper(_ helper: HelperConnection, _ op: Op, tld: String) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            let guard1 = ResumeOnce(cont)
            let timeout = Task { try? await Task.sleep(nanoseconds: helperTimeout); guard1.fail(timeoutError()) }
            guard1.onResolve = { timeout.cancel() }
            guard let proxy = helper.remoteProxy({ guard1.fail($0) }) else {
                guard1.fail(NSError(
                    domain: "KTStack",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Privileged helper is not available."]
                ))
                return
            }
            let reply: @Sendable (Bool, String?) -> Void = { ok, msg in
                if ok { guard1.succeed() }
                else { guard1.fail(NSError(
                    domain: "KTStack",
                    code: -2,
                    userInfo: [NSLocalizedDescriptionKey: msg ?? "Helper DNS action failed."]
                )) }
            }
            switch op {
            case .enable: proxy.enableDNS(tld: tld, reply: reply)
            case .disable: proxy.disableDNS(tld: tld, reply: reply)
            case .reset: proxy.resetDNS(tld: tld, reply: reply)
            }
        }
    }

    private nonisolated static func viaHelperSetTLD(_ helper: HelperConnection, old: String, new: String) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            let guard1 = ResumeOnce(cont)
            let timeout = Task { try? await Task.sleep(nanoseconds: helperTimeout); guard1.fail(timeoutError()) }
            guard1.onResolve = { timeout.cancel() }
            guard let proxy = helper.remoteProxy({ guard1.fail($0) }) else {
                guard1.fail(NSError(
                    domain: "KTStack",
                    code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Privileged helper is not available."]
                ))
                return
            }
            proxy.setTLD(old: old, new: new) { ok, msg in
                if ok { guard1.succeed() }
                else { guard1.fail(NSError(
                    domain: "KTStack",
                    code: -2,
                    userInfo: [NSLocalizedDescriptionKey: msg ?? "Helper DNS action failed."]
                )) }
            }
        }
    }

    // A hung-but-alive helper fires neither the reply nor the XPC invalidation handler, so without a
    // timeout the continuation never resumes and isBusy sticks true forever. Race the reply against
    // this deadline; whichever lands first wins.
    private static let helperTimeout: UInt64 = 25_000_000_000

    private final class ResumeOnce: @unchecked Sendable {
        private let cont: CheckedContinuation<Void, Error>
        private let lock = NSLock()
        private var done = false
        // Cancels the timeout task once the real result lands (harmless if already fired).
        var onResolve: (@Sendable () -> Void)?
        init(_ cont: CheckedContinuation<Void, Error>) {
            self.cont = cont
        }

        func succeed() {
            fire { cont.resume() }
        }

        func fail(_ error: Error) {
            fire { cont.resume(throwing: error) }
        }

        private func fire(_ block: () -> Void) {
            lock.lock(); defer { lock.unlock() }
            guard !done else { return }
            done = true; onResolve?(); block()
        }
    }

    private nonisolated static func timeoutError() -> NSError {
        NSError(domain: "KTStack", code: -5,
                userInfo: [NSLocalizedDescriptionKey: "Privileged helper did not respond in time."])
    }
}
