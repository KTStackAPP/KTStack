import Foundation

/// How a connection negotiates TLS. `require`/`verifyFull` fail closed; `verifyFull` is the default
/// for any non-loopback host so a remote/prod database can't be reached over an unverified channel.
/// The managed loopback engine uses `prefer` (its self-signed cert can't chain to a public root, but
/// the channel still encrypts — see the loopback-TLS note in the driver).
public enum TLSMode: String, Codable, Sendable, CaseIterable {
    case disable
    case prefer
    case require
    case verifyFull

    /// Non-loopback hosts default to full verification; loopback to `prefer` (encrypt, don't verify a
    /// self-signed local cert). Callers pick the default from the host, never hardcode `disable`.
    public static func defaultMode(forHost host: String) -> TLSMode {
        let loopback = host == "127.0.0.1" || host == "::1" || host == "localhost"
        return loopback ? .prefer : .verifyFull
    }
}

/// The engine a profile talks to. Carried on every profile from the start (not added per phase) so
/// the store, dialect, and driver registry can branch on it without a schema migration when
/// PostgreSQL/SQLite/Mongo land.
public enum DatabaseKind: String, Codable, Sendable, CaseIterable {
    case mysql
    case postgres
    case sqlite
    case mongodb
}

/// A saved connection's non-secret coordinates. Codable for the JSON store; the password is NEVER a
/// field here — it lives in `KeychainStore` keyed by `id`, so the on-disk JSON can be read by anyone
/// with file access without leaking credentials. `filePath` is the SQLite database file (ignored by
/// networked engines); `tlsMode` governs the transport for networked engines (ignored by SQLite).
public struct ConnectionProfile: Codable, Sendable, Identifiable, Equatable {
    public let id: UUID
    public var name: String
    public var kind: DatabaseKind
    public var host: String
    public var port: Int
    public var user: String
    public var database: String
    /// SQLite only: absolute path to the `.sqlite`/`.db` file. Nil for networked engines.
    public var filePath: String?
    public var tlsMode: TLSMode

    public init(
        id: UUID = UUID(),
        name: String,
        kind: DatabaseKind,
        host: String,
        port: Int,
        user: String,
        database: String,
        filePath: String? = nil,
        tlsMode: TLSMode? = nil
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.host = host
        self.port = port
        self.user = user
        self.database = database
        self.filePath = filePath
        self.tlsMode = tlsMode ?? .defaultMode(forHost: host)
    }

    /// The always-listed connection to the managed, on-demand MySQL engine: loopback, root, no
    /// password (the engine is initialized `--initialize-insecure`). Synthetic — never persisted to
    /// the store — and the engine may be uninstalled/stopped, so connecting still surfaces
    /// `engineNotInstalled`/`engineNotRunning`. A fixed id keeps Keychain/UI identity stable.
    public static let managedMySQL = ConnectionProfile(
        // Fixed sentinel id so Keychain/UI identity for the managed engine stays stable across launches.
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        name: "MySQL (managed)",
        kind: .mysql,
        host: "127.0.0.1",
        port: 3306,
        user: "root",
        database: "mysql",
        tlsMode: .prefer)

    /// True for the synthetic managed profile (not user-editable, not stored).
    public var isManaged: Bool { id == Self.managedMySQL.id }
}
