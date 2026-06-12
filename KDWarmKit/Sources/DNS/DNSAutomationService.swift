import Foundation
import Combine

/// App-side DNS automation. When a signing identity exists (Phase 9) it drives the privileged
/// helper over XPC; otherwise it uses the `sudo` fallback — so `.test` DNS works either way.
/// Status is derived from the filesystem (resolver file + `:53` ownership), so the UI reflects
/// reality without the helper being approved.
///
/// NOTE: on the current dev/ad-hoc build `usesHelper` is false, so the XPC branch never runs — the
/// fallback is the live path. The helper branch is wired (not dead) and goes live in Phase 9.
@MainActor
public final class DNSAutomationService: ObservableObject {
    public enum Status: Equatable, Sendable {
        case unknown
        case disabled                 // no /etc/resolver/test
        case enabled                  // resolver present
        case conflict(String)         // a foreign process holds :53
    }

    @Published public private(set) var status: Status = .unknown
    @Published public private(set) var isBusy = false
    @Published public private(set) var lastError: String?

    /// True once the build can use the live SMAppService helper (Phase 9); false on dev → fallback.
    public let usesHelper = HelperIdentity.hasSigningIdentity

    /// The live dev TLD (configurable, Phase 5), injected from `AppPreferences` at launch and baked
    /// for this service's lifetime — every resolver path + DNS op is keyed by it. A TLD CHANGE goes
    /// through `changeTLD(to:)` (old→new reconcile) and then requires an app relaunch so this and the
    /// site registry pick up the new value at init.
    public let tld: String

    nonisolated private let fallback: SudoFallbackInstaller
    nonisolated private let port53 = Port53ConflictDetector()
    nonisolated private let helper = HelperConnection()

    public init(bundledDnsmasq: URL, tld: String = AppPreferences.defaultTLD) {
        self.tld = tld
        self.fallback = SudoFallbackInstaller(bundledDnsmasq: bundledDnsmasq, tld: tld)
        refresh()
    }

    private enum Op { case enable, disable, reset }

    /// Recompute status from the live system state.
    public func refresh() {
        if let conflict = port53.check() { status = .conflict(conflict.process); return }
        status = FileManager.default.fileExists(atPath: DNSConstants.resolverPath(for: tld)) ? .enabled : .disabled
    }

    public var isEnabled: Bool { status == .enabled }

    public func enable() { perform(.enable) }
    public func disable() { perform(.disable) }
    /// Reconcile a stale/hijacked state — one root invocation (single admin prompt).
    public func reset() { perform(.reset) }

    /// Change the dev TLD from the current `tld` to `newTLD` in ONE privileged op (removes the old
    /// resolver, writes the new, rewrites the dnsmasq wildcard, restarts, flushes the cache). On the
    /// signed build this is a single XPC call; on dev it is a single admin prompt. The caller (Settings)
    /// persists the pref + prompts a relaunch ONLY on success — DNS is reconciled before the prefs flip
    /// so a cancelled prompt leaves the old TLD fully working. No-ops when `newTLD == tld`.
    public func changeTLD(to newTLD: String, completion: @escaping @MainActor (Result<Void, Error>) -> Void) {
        guard !isBusy else {
            completion(.failure(NSError(domain: "KDWarm", code: -3,
                userInfo: [NSLocalizedDescriptionKey: "Another DNS operation is in progress."])))
            return
        }
        guard newTLD != tld else { completion(.success(())); return }
        if let conflict = port53.check() {
            lastError = conflict.message; status = .conflict(conflict.process)
            completion(.failure(NSError(domain: "KDWarm", code: -4,
                userInfo: [NSLocalizedDescriptionKey: conflict.message])))
            return
        }
        isBusy = true; lastError = nil
        let usesHelper = self.usesHelper, fallback = self.fallback, helper = self.helper, old = self.tld
        Task.detached(priority: .userInitiated) {
            var failure: Error?
            do {
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

    // MARK: - Private

    private func perform(_ op: Op) {
        guard !isBusy else { return }
        if op != .disable, let conflict = port53.check() {
            lastError = conflict.message; status = .conflict(conflict.process); return
        }
        isBusy = true; lastError = nil
        let usesHelper = self.usesHelper
        let fallback = self.fallback
        let helper = self.helper
        let tld = self.tld
        Task.detached(priority: .userInitiated) {
            var failure: String?
            do {
                if usesHelper { try await Self.viaHelper(helper, op, tld: tld) }
                else { try Self.viaFallback(fallback, op) }
            } catch {
                failure = error.localizedDescription
            }
            await MainActor.run {
                self.isBusy = false
                if let failure { self.lastError = failure }
                self.refresh()
            }
        }
    }

    nonisolated private static func viaFallback(_ f: SudoFallbackInstaller, _ op: Op) throws {
        switch op {
        case .enable:  try f.runInstallWithAdminPrivileges()
        case .disable: try f.runUninstallWithAdminPrivileges()
        case .reset:   try f.runResetWithAdminPrivileges()
        }
    }

    /// Live XPC path (Phase 9). Bridges the callback-based helper reply into async, resuming once.
    nonisolated private static func viaHelper(_ helper: HelperConnection, _ op: Op, tld: String) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            let guard1 = ResumeOnce(cont)
            guard let proxy = helper.remoteProxy({ guard1.fail($0) }) else {
                guard1.fail(NSError(domain: "KDWarm", code: -1,
                                    userInfo: [NSLocalizedDescriptionKey: "Privileged helper is not available."]))
                return
            }
            let reply: @Sendable (Bool, String?) -> Void = { ok, msg in
                if ok { guard1.succeed() }
                else { guard1.fail(NSError(domain: "KDWarm", code: -2,
                                           userInfo: [NSLocalizedDescriptionKey: msg ?? "Helper DNS action failed."])) }
            }
            switch op {
            case .enable:  proxy.enableDNS(tld: tld, reply: reply)
            case .disable: proxy.disableDNS(tld: tld, reply: reply)
            case .reset:   proxy.resetDNS(tld: tld, reply: reply)
            }
        }
    }

    /// XPC `setTLD` (old→new) bridged into async, resuming once.
    nonisolated private static func viaHelperSetTLD(_ helper: HelperConnection, old: String, new: String) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            let guard1 = ResumeOnce(cont)
            guard let proxy = helper.remoteProxy({ guard1.fail($0) }) else {
                guard1.fail(NSError(domain: "KDWarm", code: -1,
                                    userInfo: [NSLocalizedDescriptionKey: "Privileged helper is not available."]))
                return
            }
            proxy.setTLD(old: old, new: new) { ok, msg in
                if ok { guard1.succeed() }
                else { guard1.fail(NSError(domain: "KDWarm", code: -2,
                                           userInfo: [NSLocalizedDescriptionKey: msg ?? "Helper DNS action failed."])) }
            }
        }
    }

    /// Guards a CheckedContinuation against the double-resume that an XPC error-handler + reply can
    /// otherwise cause (which would crash).
    private final class ResumeOnce: @unchecked Sendable {
        private let cont: CheckedContinuation<Void, Error>
        private let lock = NSLock()
        private var done = false
        init(_ cont: CheckedContinuation<Void, Error>) { self.cont = cont }
        func succeed() { fire { cont.resume() } }
        func fail(_ error: Error) { fire { cont.resume(throwing: error) } }
        private func fire(_ block: () -> Void) {
            lock.lock(); defer { lock.unlock() }
            guard !done else { return }
            done = true; block()
        }
    }
}
