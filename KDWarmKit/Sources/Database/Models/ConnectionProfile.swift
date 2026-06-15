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
        ConnectionProfile.isLoopback(host) ? .prefer : .verifyFull
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
    /// When true the session is opened read-only and the server rejects writes — the real gate behind
    /// the UI toggle (a client-side verb check alone is bypassable). Per-profile, never inferred from
    /// the host at connect time, because an SSH-tunneled prod DB looks like loopback.
    public var readOnly: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        kind: DatabaseKind,
        host: String,
        port: Int,
        user: String,
        database: String,
        filePath: String? = nil,
        tlsMode: TLSMode? = nil,
        readOnly: Bool? = nil
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
        self.readOnly = readOnly ?? Self.defaultReadOnly(forHost: host)
    }

    /// True for hosts that resolve to this machine. Loopback connections get write access and lenient
    /// TLS by default; any other host is treated as remote (read-only ON, full cert verification).
    public static func isLoopback(_ host: String) -> Bool {
        host == "127.0.0.1" || host == "::1" || host == "localhost"
    }

    /// New external (non-loopback) connections default to read-only so a saved prod connection can't
    /// take a stray write before the user opts in.
    public static func defaultReadOnly(forHost host: String) -> Bool { !isLoopback(host) }

    private enum CodingKeys: String, CodingKey {
        case id, name, kind, host, port, user, database, filePath, tlsMode, readOnly
    }

    /// Custom decode so a profile saved before `readOnly`/`tlsMode` existed still loads: an absent key
    /// falls back to the host-derived default rather than failing the whole store decode (which would
    /// back the file up and drop the user's saved connections).
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try c.decode(UUID.self, forKey: .id),
            name: try c.decode(String.self, forKey: .name),
            kind: try c.decode(DatabaseKind.self, forKey: .kind),
            host: try c.decode(String.self, forKey: .host),
            port: try c.decode(Int.self, forKey: .port),
            user: try c.decode(String.self, forKey: .user),
            database: try c.decode(String.self, forKey: .database),
            filePath: try c.decodeIfPresent(String.self, forKey: .filePath),
            tlsMode: try c.decodeIfPresent(TLSMode.self, forKey: .tlsMode),
            readOnly: try c.decodeIfPresent(Bool.self, forKey: .readOnly))
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
        tlsMode: .prefer,
        readOnly: false)

    /// True for the synthetic managed profile (not user-editable, not stored).
    public var isManaged: Bool { id == Self.managedMySQL.id }
}
