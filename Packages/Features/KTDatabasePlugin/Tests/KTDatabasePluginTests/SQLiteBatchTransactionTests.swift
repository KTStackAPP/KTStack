import XCTest
@testable import KTDatabasePlugin

final class SQLiteBatchTransactionTests: XCTestCase {
    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("ktstack-sqlite-batch-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
    }

    private func makeDriver() -> SQLiteDriver {
        let path = tempDir.appendingPathComponent("test.db").path
        let profile = ConnectionProfile(
            name: "test",
            kind: .sqlite,
            host: "",
            port: 0,
            user: "",
            database: SQLiteDriver.mainDatabase,
            filePath: path,
            readOnly: false
        )
        return SQLiteDriver(profile: profile)
    }

    func testBatchCommitInsertUpdateDelete() async throws {
        let driver = makeDriver()
        _ = try await driver.query("CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT NOT NULL)", database: nil)
        _ = try await driver.query("INSERT INTO users (id, name) VALUES (1, 'Alice'), (2, 'Bob')", database: nil)

        let steps: [WriteStep] = [
            WriteStep(
                statement: DMLStatement(sql: "INSERT INTO users (id, name) VALUES (?, ?)", binds: [.int(3), .text("Charlie")]),
                expectedAffected: 1
            ),
            WriteStep(
                statement: DMLStatement(sql: "UPDATE users SET name = ? WHERE id = ?", binds: [.text("Alice Updated"), .int(1)]),
                expectedAffected: 1
            ),
            WriteStep(
                statement: DMLStatement(sql: "DELETE FROM users WHERE id = ?", binds: [.int(2)]),
                expectedAffected: 1
            )
        ]

        try await driver.executeTransaction(steps, database: SQLiteDriver.mainDatabase)

        let result = try await driver.query("SELECT id, name FROM users ORDER BY id", database: nil)
        XCTAssertEqual(result.rows.count, 2)
        XCTAssertEqual(result.rows[0][0], .int(1))
        XCTAssertEqual(result.rows[0][1], .text("Alice Updated"))
        XCTAssertEqual(result.rows[1][0], .int(3))
        XCTAssertEqual(result.rows[1][1], .text("Charlie"))
    }

    func testBatchRollbackOnWriteConflict() async throws {
        let driver = makeDriver()
        _ = try await driver.query("CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT NOT NULL)", database: nil)
        _ = try await driver.query("INSERT INTO users (id, name) VALUES (1, 'Alice')", database: nil)

        let steps: [WriteStep] = [
            WriteStep(
                statement: DMLStatement(sql: "INSERT INTO users (id, name) VALUES (?, ?)", binds: [.int(2), .text("Bob")]),
                expectedAffected: 1
            ),
            WriteStep(
                statement: DMLStatement(sql: "UPDATE users SET name = ? WHERE id = ?", binds: [.text("Ghost"), .int(999)]),
                expectedAffected: 1
            )
        ]

        do {
            try await driver.executeTransaction(steps, database: SQLiteDriver.mainDatabase)
            XCTFail("Expected write conflict error")
        } catch {
            let result = try await driver.query("SELECT id, name FROM users", database: nil)
            XCTAssertEqual(result.rows.count, 1)
            XCTAssertEqual(result.rows[0][1], .text("Alice"))
        }
    }

    func testBatchNoOpKeyCheck() async throws {
        let driver = makeDriver()
        _ = try await driver.query("CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT NOT NULL)", database: nil)
        _ = try await driver.query("INSERT INTO users (id, name) VALUES (1, 'Alice')", database: nil)

        let steps: [WriteStep] = [
            WriteStep(
                statement: DMLStatement(sql: "UPDATE users SET name = ? WHERE id = ? AND name != ?", binds: [.text("Alice"), .int(1), .text("Alice")]),
                expectedAffected: 1,
                noOpKeyCheck: DMLStatement(sql: "SELECT 1 FROM users WHERE id = ?", binds: [.int(1)])
            )
        ]

        try await driver.executeTransaction(steps, database: SQLiteDriver.mainDatabase)
        let result = try await driver.query("SELECT name FROM users WHERE id = 1", database: nil)
        XCTAssertEqual(result.rows.first?.first, .text("Alice"))
    }
}
