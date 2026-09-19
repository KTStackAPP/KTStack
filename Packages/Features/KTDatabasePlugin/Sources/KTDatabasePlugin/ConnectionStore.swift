import Combine
import Foundation
import KTStackCore

@MainActor
public final class ConnectionStore: ObservableObject {
    @Published public private(set) var profiles: [ConnectionProfile] = []

    public var onChange: (() -> Void)?

    private let storeURL: URL
    private let keychain: KeychainStore

    public init(storeURL: URL, keychain: KeychainStore = KeychainStore(service: DatabaseKeychain.service)) {
        self.storeURL = storeURL
        self.keychain = keychain
        load()
    }

    public var allProfiles: [ConnectionProfile] {
        ConnectionProfile.managedProfiles + profiles
    }

    public func add(_ profile: ConnectionProfile, password: String? = nil) {
        let key = deduplicationKey(for: profile)
        if let existingIdx = profiles.firstIndex(where: { deduplicationKey(for: $0) == key }) {
            profiles[existingIdx] = profile
        } else {
            profiles.append(profile)
        }
        setPassword(password, for: profile)
        persist()
    }

    public func update(_ profile: ConnectionProfile, password: String? = nil) {
        guard let idx = profiles.firstIndex(where: { $0.id == profile.id }) else { return }
        profiles[idx] = profile
        setPassword(password, for: profile)
        persist()
    }

    private func setPassword(_ password: String?, for profile: ConnectionProfile) {
        guard let password, !password.isEmpty else { return }
        do {
            try keychain.set(password, account: profile.id.uuidString)
        } catch {
            NSLog("KTStack: failed to store connection password in Keychain: \(error.localizedDescription)")
        }
    }

    public func remove(_ profile: ConnectionProfile) {
        profiles.removeAll { $0.id == profile.id }
        try? keychain.delete(account: profile.id.uuidString)
        persist()
    }

    private func load() {
        defer { onChange?() }
        guard let data = try? Data(contentsOf: storeURL) else { return }
        if let decoded = try? JSONDecoder().decode([ConnectionProfile].self, from: data) {
            let unique = deduplicated(decoded)
            profiles = unique
            if unique.count != decoded.count {
                persist()
            }
        } else {
            let backup = storeURL.appendingPathExtension("bak")
            try? FileManager.default.removeItem(at: backup)
            try? FileManager.default.copyItem(at: storeURL, to: backup)
            NSLog("KTStack: could not decode connection store; backed up to \(backup.lastPathComponent)")
        }
    }

    private func persist() {
        do {
            try FileManager.default.createDirectory(
                at: storeURL.deletingLastPathComponent(),
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
            let data = try JSONEncoder().encode(profiles)
            try data.write(to: storeURL, options: .atomic)
        } catch {
            NSLog("KTStack: failed to persist connection store: \(error.localizedDescription)")
        }
        onChange?()
    }

    private func deduplicated(_ list: [ConnectionProfile]) -> [ConnectionProfile] {
        var seen = Set<String>()
        var result: [ConnectionProfile] = []
        for profile in list {
            let key = deduplicationKey(for: profile)
            if seen.insert(key).inserted {
                result.append(profile)
            }
        }
        return result
    }

    private func deduplicationKey(for profile: ConnectionProfile) -> String {
        "\(profile.kind.rawValue)|\(profile.host.lowercased())|\(profile.port)|\(profile.user)|\(profile.database)|\(profile.name)"
    }
}
