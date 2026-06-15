import Foundation
import MySQLNIO
import NIOCore

/// Pure translation of MySQLNIO/NIO failures into the typed `DatabaseError` surface, plus the
/// string-literal escaping the driver uses for `information_schema` filters. Kept separate from
/// `MySQLDriver` so it carries no connection state and can be unit-tested without an engine.
enum MySQLErrorMapper {
    /// Map a raw driver error to a typed `DatabaseError`. A connection refused on the managed engine
    /// means installed-but-down (`engineNotRunning`); auth failures carry the server message distinct
    /// from SQL syntax errors so the UI can tell "wrong password" from "bad query". `isManaged` selects
    /// the managed-engine wording for a refused socket.
    static func map(_ error: any Error, isManaged: Bool) -> DatabaseError {
        if let dbError = error as? DatabaseError { return dbError }
        if let mysql = error as? MySQLError {
            switch mysql {
            case .invalidSyntax(let message): return .syntax(message)
            case .server(let packet):
                // Access-denied codes are authentication failures, not SQL errors — without this they
                // collapse into `.syntax` and the auth case never surfaces.
                switch packet.errorCode {
                case .ACCESS_DENIED_ERROR, .DBACCESS_DENIED_ERROR, .ACCESS_DENIED_NO_PASSWORD_ERROR:
                    return .authenticationFailed(packet.errorMessage)
                default:
                    return .syntax(packet.errorMessage)
                }
            case .closed: return .connection("Connection closed")
            default:      return .connection(String(describing: mysql))
            }
        }
        if let channel = error as? ChannelError, case .connectTimeout = channel {
            return .timeout
        }
        if isConnectionRefused(error) {
            return isManaged ? .engineNotRunning(kind: "MySQL") : .connection("Connection refused")
        }
        return .connection(String(describing: error))
    }

    /// True when `error` is (or wraps) a connection-refused. NIO usually surfaces a refused connect as
    /// `NIOConnectionError` aggregating the per-address `IOError(ECONNREFUSED)`, so a bare `IOError`
    /// check alone would miss it — unwrap one level into the aggregated failures.
    static func isConnectionRefused(_ error: any Error) -> Bool {
        if let io = error as? IOError, io.errnoCode == ECONNREFUSED { return true }
        if let aggregate = error as? NIOConnectionError {
            return aggregate.connectionErrors.contains {
                ($0.error as? IOError)?.errnoCode == ECONNREFUSED
            }
        }
        return false
    }

    /// Escape a string for use as a SQL string literal (single-quoted). Used only for
    /// `information_schema` filters where the value is data, not an identifier — doubles embedded
    /// single quotes and backslashes so a schema/table name can't break out of the quoted literal.
    /// Rejects NUL (can truncate at the server's C-string boundary) for parity with `quoteIdent`.
    static func quoteLiteral(_ value: String) throws -> String {
        guard !value.contains("\u{0}") else {
            throw DatabaseError.connection("Illegal character in SQL literal")
        }
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "''")
        return "'\(escaped)'"
    }
}
