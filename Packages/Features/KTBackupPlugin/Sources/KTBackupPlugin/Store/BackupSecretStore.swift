import Foundation

public enum BackupSecretKind: String, Sendable, CaseIterable {
    case s3SecretAccessKey = "s3-secret"
    case googleRefreshToken = "google-refresh-token"
    case googleClientSecret = "google-client-secret"
}

public protocol BackupSecretStoring: Sendable {
    func secret(_ kind: BackupSecretKind, for destinationID: UUID) throws -> String?
    func setSecret(_ value: String, _ kind: BackupSecretKind, for destinationID: UUID) throws
    func deleteSecret(_ kind: BackupSecretKind, for destinationID: UUID) throws
}

public extension BackupSecretStoring {
    func deleteAllSecrets(for destinationID: UUID) {
        for kind in BackupSecretKind.allCases {
            try? deleteSecret(kind, for: destinationID)
        }
    }

    static func account(_ kind: BackupSecretKind, _ destinationID: UUID) -> String {
        "\(destinationID.uuidString).\(kind.rawValue)"
    }
}
