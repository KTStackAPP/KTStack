import Foundation

public struct OverlaySecretStore: BackupSecretStoring {
    let base: any BackupSecretStoring
    let destinationID: UUID
    let overrides: [BackupSecretKind: String]

    public init(base: any BackupSecretStoring, destinationID: UUID, overrides: [BackupSecretKind: String]) {
        self.base = base
        self.destinationID = destinationID
        self.overrides = overrides
    }

    public func secret(_ kind: BackupSecretKind, for destinationID: UUID) throws -> String? {
        if destinationID == self.destinationID, let value = overrides[kind]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !value.isEmpty {
            return value
        }
        return try base.secret(kind, for: destinationID)
    }

    public func setSecret(_ value: String, _ kind: BackupSecretKind, for destinationID: UUID) throws {
        try base.setSecret(value, kind, for: destinationID)
    }

    public func deleteSecret(_ kind: BackupSecretKind, for destinationID: UUID) throws {
        try base.deleteSecret(kind, for: destinationID)
    }
}
