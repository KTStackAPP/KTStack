import Foundation
import Combine

/// Source of truth for user-saved connection profiles. Persists to `config/database/connections.json`
/// and mirrors `SiteRegistry`: `@MainActor`-isolated `@Published` state, `onChange` after every
/// mutation (and load), reload-on-init. Passwords are NOT stored here — `remove` also clears the
/// profile's Keychain item so deleting a connection leaves no orphaned secret.
@MainActor
public final class ConnectionStore: ObservableObject {
    /// User-added profiles only — exactly what persists to JSON.
    @Published public private(set) var profiles: [ConnectionProfile] = []

    /// Fired after any successful mutation (and after load), on the main actor.
    public var onChange: (() -> Void)?

    private let storeURL: URL
    private let keychain: KeychainStore

    public init(storeURL: URL, keychain: KeychainStore = KeychainStore()) {
        self.storeURL = storeURL
        self.keychain = keychain
        load()
    }

    /// Profiles surfaced to the UI: the always-listed synthetic managed engine first, then the saved
    /// ones. The managed profile is never in `profiles`/JSON, so it can't be edited or removed.
    public var allProfiles: [ConnectionProfile] {
        [.managedMySQL] + profiles
    }

    // MARK: - Mutators

    /// Append a new profile and persist. (Callers store the password separately via `KeychainStore`.)
    public func add(_ profile: ConnectionProfile) {
        profiles.append(profile)
        persist()
    }

    /// Replace an existing profile (matched by id) in place; no-op if absent.
    public func update(_ profile: ConnectionProfile) {
        guard let idx = profiles.firstIndex(where: { $0.id == profile.id }) else { return }
        profiles[idx] = profile
        persist()
    }

    /// Remove a profile and clear its Keychain password so no secret outlives the connection.
    public func remove(_ profile: ConnectionProfile) {
        profiles.removeAll { $0.id == profile.id }
        try? keychain.delete(account: profile.id.uuidString)
        persist()
    }

    // MARK: - Persistence

    private func load() {
        defer { onChange?() }
        guard let data = try? Data(contentsOf: storeURL) else { return }   // absent file → fresh
        if let decoded = try? JSONDecoder().decode([ConnectionProfile].self, from: data) {
            profiles = decoded
        } else {
            // Present but undecodable (corrupt / old schema): back it up rather than overwrite it on
            // the next persist, so a user's saved connections aren't silently lost.
            let backup = storeURL.appendingPathExtension("bak")
            try? FileManager.default.removeItem(at: backup)
            try? FileManager.default.copyItem(at: storeURL, to: backup)
            NSLog("KDWarm: could not decode connection store; backed up to \(backup.lastPathComponent)")
        }
    }

    private func persist() {
        do {
            try FileManager.default.createDirectory(
                at: storeURL.deletingLastPathComponent(),
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700])
            let data = try JSONEncoder().encode(profiles)
            try data.write(to: storeURL, options: .atomic)
        } catch {
            NSLog("KDWarm: failed to persist connection store: \(error.localizedDescription)")
        }
        onChange?()
    }
}
