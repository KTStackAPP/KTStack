import Foundation

/// Typed failures surfaced by every database driver. UI maps these to user-facing messages; callers
/// switch on the case rather than parsing strings. `engineNotInstalled`/`engineNotRunning` exist
/// because the managed engine is on-demand — it can be absent or stopped on a clean machine, so a
/// connect attempt must distinguish "you never installed MySQL" from "MySQL is down" from "wrong
/// password", never collapse them into one opaque connection error.
public enum DatabaseError: Error, Equatable, Sendable {
    /// The managed engine for this kind isn't installed (no marker binary under `runtimes/<kind>/`).
    case engineNotInstalled(kind: String)
    /// The engine is installed but not accepting connections (process down, socket refused).
    case engineNotRunning(kind: String)
    /// Reached the server but authentication failed (bad user/password, denied host).
    case authenticationFailed(String)
    /// The server rejected the SQL (parse/semantic error). Carries the server message verbatim.
    case syntax(String)
    /// The operation exceeded its deadline before the server responded.
    case timeout
    /// A connection-level failure not covered above (DNS, TLS handshake, socket). Carries detail.
    case connection(String)
    /// The driver received a response it couldn't interpret (protocol desync, unexpected packet).
    case unexpectedResponse(String)

    public var message: String {
        switch self {
        case .engineNotInstalled(let kind): return "The \(kind) engine isn't installed."
        case .engineNotRunning(let kind):   return "The \(kind) engine isn't running."
        case .authenticationFailed(let d):  return "Authentication failed: \(d)"
        case .syntax(let d):                return "SQL error: \(d)"
        case .timeout:                      return "The database operation timed out."
        case .connection(let d):            return "Connection failed: \(d)"
        case .unexpectedResponse(let d):    return "Unexpected database response: \(d)"
        }
    }
}

extension DatabaseError: LocalizedError {
    public var errorDescription: String? { message }
}
