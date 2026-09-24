import XCTest
@testable import KTDatabasePlugin

final class PostgresSearchPathTests: XCTestCase {
    private final class RecordingConnection: SessionConnection, @unchecked Sendable {
        private let lock = NSLock()
        private var _schemas: [String] = []
        var schemas: [String] { lock.withLock { _schemas } }
        var isLive: Bool { true }

        func useDatabase(_ database: String) async throws {
            lock.withLock { _schemas.append(database) }
        }

        func runText(_: String) async throws -> QueryResult { QueryResult(columns: [], rows: []) }
        func runSelect(_: DMLStatement) async throws -> QueryResult { QueryResult(columns: [], rows: []) }
        func shutdown() async {}
    }

    func testRunSelectAppliesTheRequestedSchema() async throws {
        let connection = RecordingConnection()
        let driver = PostgresDriver(
            profile: .managedPostgres,
            password: nil,
            tools: FakeDatabaseTools.allInstalled,
            session: ConnectionSession { connection }
        )
        let statement = DMLStatement(sql: "SELECT * FROM \"orders\" LIMIT $1", binds: [.int(10)])
        _ = try await driver.runSelect(statement, database: "sales")
        _ = try await driver.runSelect(statement, database: "archive")
        XCTAssertEqual(connection.schemas, ["sales", "archive"])
    }
}
