import Foundation
import KTStackCore

public struct KeychainBackupSecretStore: BackupSecretStoring {
    public static let service = "com.ktstack.backups"

    private let keychain: KeychainStore

    public init(service: String = KeychainBackupSecretStore.service) {
        keychain = KeychainStore(service: service)
    }

    public func secret(_ kind: BackupSecretKind, for destinationID: UUID) throws -> String? {
        try keychain.get(account: Self.account(kind, destinationID))
    }

    public func setSecret(_ value: String, _ kind: BackupSecretKind, for destinationID: UUID) throws {
        try keychain.set(value, account: Self.account(kind, destinationID))
    }

    public func deleteSecret(_ kind: BackupSecretKind, for destinationID: UUID) throws {
        try keychain.delete(account: Self.account(kind, destinationID))
    }
}
