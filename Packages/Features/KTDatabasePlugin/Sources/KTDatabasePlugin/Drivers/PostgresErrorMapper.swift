import Foundation
import NIOCore
import NIOSSL
import PostgresNIO

/// Translates PostgresNIO failures into the shared `DatabaseError`. Server errors carry a SQLSTATE
/// (`PSQLError.serverInfo[.sqlState]`); class `28` is "invalid authorization", everything else with a
/// server message is the user's SQL/permission problem. No server response means a transport failure —
/// distinguished as engine-not-running for the managed instance (connection refused) vs a readable
/// connection error built from `PSQLError.code`/`underlying` for external hosts.
enum PostgresErrorMapper {
    static func map(_ error: any Error, isManaged: Bool) -> DatabaseError {
        if let dbError = error as? DatabaseError { return dbError }
        if let pg = error as? PSQLError {
            if let info = pg.serverInfo {
                let message = info[.message] ?? String(describing: pg)
                if let state = info[.sqlState], state.hasPrefix("28") {
                    return .authenticationFailed(message)
                }
                return .syntax(message)
            }
            // description của PSQLError luôn là chuỗi che, nguyên nhân nằm ở code/underlying.
            if let underlying = pg.underlying, isConnectionRefused(underlying) {
                return refused(isManaged: isManaged)
            }
            return .connection(transportMessage(code: pg.code, underlying: pg.underlying))
        }
        if isConnectionRefused(error) { return refused(isManaged: isManaged) }
        return .connection(String(describing: error))
    }

    static func transportMessage(code: PSQLError.Code, underlying: (any Error)?) -> String {
        if code == .sslUnsupported {
            return "Server does not accept TLS. Set TLS to prefer or disable."
        }
        if let underlying, isTLSFailure(underlying) {
            return "TLS handshake failed (\(underlying)). If the server uses a self-signed certificate, set TLS to prefer."
        }
        if code == .unsupportedAuthMechanism {
            return "Server asks for an authentication method that is not supported."
        }
        if let underlying { return String(describing: underlying) }
        return "\(code)"
    }

    private static func refused(isManaged: Bool) -> DatabaseError {
        isManaged ? .engineNotRunning(kind: "PostgreSQL") : .connection("Connection refused")
    }

    private static func isTLSFailure(_ error: any Error) -> Bool {
        error is NIOSSLError || error is BoringSSLError || error is NIOSSLExtraError
    }

    static func isConnectionRefused(_ error: any Error) -> Bool {
        if let io = error as? IOError, io.errnoCode == ECONNREFUSED { return true }
        if let aggregate = error as? NIOConnectionError {
            return aggregate.connectionErrors.contains {
                ($0.error as? IOError)?.errnoCode == ECONNREFUSED
            }
        }
        return false
    }
}
