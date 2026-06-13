import Foundation
import Combine

/// The single persisted-preferences layer. Backed by `UserDefaults.standard` (the app already uses
/// `.standard` for window-restore — one domain, no scattered keys). Owned by the app (one instance,
/// injected into the Settings/Dashboard scenes); `KDWarmKit` consumers (`SiteRegistry`, DNS) read the
/// raw values via init-injection rather than reaching for a global singleton (testability).
///
/// Both values bake in at app launch for their consumers: the sites root and the dev TLD are read
/// once when `LocalServerController`/`DNSAutomationService` are constructed, so a change here takes
/// effect on the next launch (the TLD change additionally reconciles root DNS up front — Phase 5).
@MainActor
public final class AppPreferences: ObservableObject {
    public static let defaultTLD = "test"

    /// The vetted TLDs the picker offers. `.dev` is deliberately ABSENT — it is HSTS-preloaded, so
    /// browsers force HTTPS on every `*.dev` name and a plain-http local site breaks; real public
    /// TLDs are absent so a local name can never shadow a routable one. No free-text entry.
    /// `localhost` is included but caveated: macOS already resolves it to loopback, so a wildcard
    /// `*.localhost` resolver is mostly redundant (kept for users who want the explicit dnsmasq path).
    public static let safeTLDs = ["test", "localhost", "home.arpa", "internal"]

    /// Default browse/serve root (`~/Sites/WWW`) — the fallback when the user hasn't chosen one.
    public static var defaultSitesRootPath: String { AppSupportPaths.defaultSitesRoot.path }

    @Published public private(set) var sitesRootPath: String
    @Published public private(set) var tld: String

    private let defaults: UserDefaults
    private enum Key {
        static let sitesRoot = "KDWarm.sitesRootPath"
        static let tld = "KDWarm.tld"
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.sitesRootPath = defaults.string(forKey: Key.sitesRoot) ?? Self.defaultSitesRootPath
        let stored = defaults.string(forKey: Key.tld) ?? Self.defaultTLD
        // Guard against a hand-edited/corrupt stored value poisoning every consumer at launch.
        self.tld = Self.isValidTLD(stored) ? stored : Self.defaultTLD
    }

    /// `~/Sites/WWW` (or the user's chosen root) as a URL.
    public var sitesRootURL: URL { URL(fileURLWithPath: sitesRootPath) }

    // MARK: - Mutators (validate before persisting)

    /// Persist a new sites root. Ignores an empty path.
    public func setSitesRootPath(_ path: String) {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        sitesRootPath = trimmed
        defaults.set(trimmed, forKey: Key.sitesRoot)
    }

    /// Validate + persist a new TLD. Returns `false` (and changes nothing) on an invalid value, so
    /// the caller can surface an inline error. Persists only — it does NOT reconfigure DNS; the
    /// Settings flow runs the root reconcile + relaunch prompt (Phase 5).
    @discardableResult
    public func setTLD(_ raw: String) -> Bool {
        // Validate the trimmed value as-is (do NOT lowercase first): an uppercase entry like `My.Test`
        // is invalid input to surface, not something to silently normalize. The picker only ever
        // supplies lowercase `safeTLDs`, so this strictness only affects programmatic/free-text use.
        let candidate = raw.trimmingCharacters(in: .whitespaces)
        guard candidate != tld else { return true }
        guard Self.isValidTLD(candidate) else { return false }
        tld = candidate
        defaults.set(candidate, forKey: Key.tld)
        return true
    }

    // MARK: - Validation

    /// One or more lowercase RFC-1123 labels joined by single dots (`test`, `home.arpa`). Rejects
    /// uppercase, spaces, leading/trailing/double dots, and empty labels. Public-TLD safety is a
    /// separate concern enforced by `safeTLDs` in the picker — this only checks hostname syntax.
    /// Delegates to the shared privileged-boundary validator so the app and the root paths (helper +
    /// sudo fallback) accept exactly the same set.
    public static func isValidTLD(_ s: String) -> Bool { DNSConstants.isValidTLD(s) }
}
