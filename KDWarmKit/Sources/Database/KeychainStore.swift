import Foundation
import Security

/// Stores connection passwords in the macOS Keychain as generic-password items, keyed by the
/// connection profile's id (the `account`). The on-disk profile JSON carries no secret — this is the
/// only place a password lives, so a profile export or a file-read leaks nothing.
///
/// Security attrs are pinned, not configurable: items are `WhenUnlockedThisDeviceOnly` (no access
/// while locked, never migrated to a new device via backup) and non-synchronizable (kept out of
/// iCloud Keychain). DB credentials are machine-local by policy; tests read these constants rather
/// than overriding them.
public struct KeychainStore: Sendable {
    /// Most-restrictive accessibility: readable only while the device is unlocked, and never copied
    /// to another device. Pinned as a security policy — not loosened for test convenience.
    public static let accessibleAttr = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
    /// iCloud Keychain sync is off so credentials never leave the machine.
    public static let synchronizable = false

    /// Keychain service string namespacing these items. Production is `com.kdwarm.db`; tests pass a
    /// dedicated service so they never collide with real credentials.
    private let service: String

    public init(service: String = "com.kdwarm.db") {
        self.service = service
    }

    /// Base query identifying one account's item within this service. `synchronizable = false` scopes
    /// every operation to non-synced items only, so a synced item could never shadow a local one.
    private func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: Self.synchronizable,
        ]
    }

    /// Store (or replace) the password for an account. Updates in place when the item exists so a
    /// re-save doesn't create a duplicate item the next `get` would ambiguously match.
    public func set(_ password: String, account: String) throws {
        let data = Data(password.utf8)
        let query = baseQuery(account: account)

        let updateStatus = SecItemUpdate(
            query as CFDictionary,
            [kSecValueData as String: data] as CFDictionary)
        if updateStatus == errSecSuccess { return }
        guard updateStatus == errSecItemNotFound else {
            throw keychainError(updateStatus, "update password")
        }

        var insert = query
        insert[kSecValueData as String] = data
        insert[kSecAttrAccessible as String] = Self.accessibleAttr
        let addStatus = SecItemAdd(insert as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw keychainError(addStatus, "add password")
        }
    }

    /// The stored password for an account, or nil when no item exists.
    public func get(account: String) throws -> String? {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        switch status {
        case errSecSuccess:
            guard let data = item as? Data else { return nil }
            return String(decoding: data, as: UTF8.self)
        case errSecItemNotFound:
            return nil
        default:
            throw keychainError(status, "read password")
        }
    }

    /// Remove an account's password. A missing item is not an error (delete is idempotent).
    public func delete(account: String) throws {
        let status = SecItemDelete(baseQuery(account: account) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw keychainError(status, "delete password")
        }
    }

    private func keychainError(_ status: OSStatus, _ action: String) -> DatabaseError {
        let detail = SecCopyErrorMessageString(status, nil) as String? ?? "OSStatus \(status)"
        return .connection("Keychain \(action) failed: \(detail)")
    }
}
