import Foundation

public enum BackupRetention {
    public static func objectsToPrune(_ objects: [RemoteBackupObject], keepLast: Int) -> [RemoteBackupObject] {
        let newestFirst = objects.sorted { lhs, rhs in
            let left = lhs.createdAt ?? .distantPast
            let right = rhs.createdAt ?? .distantPast
            return left == right ? lhs.name > rhs.name : left > right
        }
        return Array(newestFirst.dropFirst(max(1, keepLast)))
    }

    public static func prune(_ client: any BackupDestinationClient, planID: UUID, keepLast: Int) async -> [String] {
        do {
            let candidates = objectsToPrune(try await client.list(ownedBy: planID), keepLast: keepLast)
            var warnings: [String] = []
            for object in candidates {
                if case let .skipped(reason) = try await client.moveToTrash(object) {
                    warnings.append(reason)
                    break
                }
            }
            return warnings
        } catch {
            return ["Retention cleanup didn't finish: \(error.localizedDescription)"]
        }
    }
}
