import NIOCore
import NIOPosix
import NIOSSL
import PostgresNIO
import XCTest
@testable import KTDatabasePlugin

final class PostgresErrorMapperTests: XCTestCase {
    func testSSLUnsupportedTellsUserToLowerTLSMode() {
        let message = PostgresErrorMapper.transportMessage(code: .sslUnsupported, underlying: nil)
        XCTAssertTrue(message.contains("does not accept TLS"))
    }

    func testHandshakeFailureNamesTLS() {
        let message = PostgresErrorMapper.transportMessage(
            code: .connectionError,
            underlying: NIOSSLError.handshakeFailed(.unknownError([]))
        )
        XCTAssertTrue(message.hasPrefix("TLS handshake failed"))
    }

    func testOtherTransportErrorKeepsUnderlyingText() {
        let timeout = ChannelError.connectTimeout(.seconds(10))
        let message = PostgresErrorMapper.transportMessage(code: .connectionError, underlying: timeout)
        XCTAssertEqual(message, String(describing: timeout))
    }

    func testRefusedManagedEngineSurfacesEngineNotRunning() async throws {
        let refused = try await connectionError(port: closedPort())
        guard case .engineNotRunning = PostgresErrorMapper.map(refused, isManaged: true) else {
            return XCTFail("refused connect to the managed engine should surface engineNotRunning")
        }
    }

    func testRefusedExternalHostSurfacesConnectionRefused() async throws {
        let refused = try await connectionError(port: closedPort())
        guard case let .connection(message) = PostgresErrorMapper.map(refused, isManaged: false) else {
            return XCTFail("refused connect to an external host should surface a connection error")
        }
        XCTAssertEqual(message, "Connection refused")
    }

    private func closedPort() throws -> Int {
        let channel = try ServerBootstrap(group: MultiThreadedEventLoopGroup.singleton)
            .bind(host: "127.0.0.1", port: 0).wait()
        let port = channel.localAddress?.port ?? 1
        try channel.close().wait()
        return port
    }

    private func connectionError(port: Int) async throws -> any Error {
        let configuration = PostgresConnection.Configuration(
            host: "127.0.0.1", port: port, username: "x", password: nil, database: nil, tls: .disable
        )
        do {
            let connection = try await PostgresConnection.connect(
                on: MultiThreadedEventLoopGroup.singleton.next(),
                configuration: configuration, id: 1, logger: .init(label: "test")
            )
            try await connection.close()
            throw XCTSkip("port \(port) unexpectedly accepted a connection")
        } catch let error as PSQLError {
            return error
        }
    }
}
