import Foundation

public extension BackupSet {
    func belongs(to profile: ConnectionProfile) -> Bool {
        guard let profileID else { return false }
        return profileID == profile.id
    }

    func targetWarning(for profile: ConnectionProfile) -> String? {
        guard !belongs(to: profile) else { return nil }
        let target = "\(profile.name) (\(profile.host)\(profile.port > 0 ? ":\(profile.port)" : ""))"
        guard profileID != nil else {
            return "This backup was made before KTStack recorded its connection. Restoring writes into \(target)."
        }
        let source = "\(profileName) (\(host)\(port.map { ":\($0)" } ?? ""))"
        return "This backup came from \(source). Restoring writes into a different connection: \(target)."
    }
}
