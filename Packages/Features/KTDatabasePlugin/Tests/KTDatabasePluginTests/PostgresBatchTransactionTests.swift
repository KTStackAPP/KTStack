import KTPlatformContracts
import KTStackCore
import XCTest
@testable import KTDatabasePlugin

final class PostgresBatchTransactionTests: XCTestCase {
    private func makeDriver() throws -> PostgresDriver {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["KTSTACK_DB_IT"] == "1",
            "Set KTSTACK_DB_IT=1 with PostgreSQL running on :5432."
        )
        return PostgresDriver(profile: .managedPostgres, password: nil, tools: FakeDatabaseTools.allInstalled)
    }

    func testBatchCommitIntegrationWhenRunning() async throws {
        let driver = try makeDriver()
        let tableName = "kt_pg_batch_test_\(Int.random(in: 1000...9999))"
        _ = try await driver.query("CREATE TABLE \(tableName) (id INT PRIMARY KEY, name TEXT NOT NULL)", database: "public")
        defer {
            Task {
                _ = try? await driver.query("DROP TABLE IF EXISTS \(tableName)", database: "public")
            }
        }

        let steps: [WriteStep] = [
            WriteStep(
                statement: DMLStatement(sql: "INSERT INTO \(tableName) (id, name) VALUES ($1, $2)", binds: [.int(1), .text("Alice")]),
                expectedAffected: 1
            ),
            WriteStep(
                statement: DMLStatement(sql: "UPDATE \(tableName) SET name = $1 WHERE id = $2", binds: [.text("Alice Updated"), .int(1)]),
                expectedAffected: 1
            )
        ]

        try await driver.executeTransaction(steps, database: "public")
        let result = try await driver.query("SELECT id, name FROM \(tableName) WHERE id = 1", database: "public")
        XCTAssertEqual(result.rows.first?[1], .text("Alice Updated"))
    }

    func testEmptyStepsNoOp() async throws {
        let profile = ConnectionProfile(
            name: "test",
            kind: .postgres,
            host: "127.0.0.1",
            port: 5432,
            user: "postgres",
            database: "postgres"
        )
        let driver = PostgresDriver(profile: profile, password: nil, tools: FakeDatabaseTools.allInstalled)
        try await driver.executeTransaction([], database: "postgres")
    }
}
