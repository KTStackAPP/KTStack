import KTPlatformContracts
import KTStackCore
import XCTest
@testable import KTDatabasePlugin

/// Opt-in integration test for the staged batch commit path end-to-end against the managed MySQL
/// engine. Gated on `KTSTACK_DB_IT=1` + an engine on :3306. Proves one transaction per commit
/// (update + delete + insert together), and that any failing step rolls the whole batch back.
final class MySQLBatchCommitIntegrationTests: XCTestCase {

    private var opened: [MySQLDriver] = []
    private let schema = "ktstack_batch_it"

    private let columns = [
        ColumnInfo(name: "id", dataType: "int", isNullable: false, isPrimaryKey: true),
        ColumnInfo(name: "name", dataType: "varchar(50)", isNullable: true, isPrimaryKey: false),
    ]

    override func tearDown() async throws {
        if let driver = opened.first { _ = try? await driver.query("DROP DATABASE IF EXISTS \(schema)", database: nil) }
        for driver in opened { await driver.closeSession() }
        opened = []
    }

    private func makeDriver() throws -> MySQLDriver {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["KTSTACK_DB_IT"] == "1",
            "Set KTSTACK_DB_IT=1 with the MySQL engine installed + running on :3306."
        )
        let driver = MySQLDriver(profile: .managedMySQL, password: nil, tools: FakeDatabaseTools.allInstalled)
        opened.append(driver)
        return driver
    }

    private func seed(_ driver: MySQLDriver) async throws {
        _ = try await driver.query("DROP DATABASE IF EXISTS \(schema)", database: nil)
        _ = try await driver.query("CREATE DATABASE \(schema)", database: nil)
        _ = try await driver.query("CREATE TABLE \(schema).t (id INT PRIMARY KEY, name VARCHAR(50))", database: nil)
        _ = try await driver.query("INSERT INTO \(schema).t (id, name) VALUES (1, 'a'), (2, 'b')", database: nil)
    }

    private func editor(_ driver: MySQLDriver) -> StagedTableEditor {
        StagedTableEditor(
            schema: schema, table: "t", dialect: .forKind(.mysql),
            columns: columns, driver: driver, database: schema
        )
    }

    func testBatchUpdateDeleteInsertCommitInOneTransaction() async throws {
        let driver = try makeDriver()
        try await seed(driver)
        let staged = editor(driver)

        _ = try staged.stageUpdate(row: ["id": .int(1), "name": .text("a")], column: "name", edit: .value("a2"))
        try staged.stageDelete(row: ["id": .int(2), "name": .text("b")])
        _ = staged.stageInsert(values: [ColumnValue(column: "id", value: .int(3)), ColumnValue(column: "name", value: .text("c"))])

        try await staged.commit()

        let page = try await driver.paginatedRows(database: schema, table: "t", limit: 10, offset: 0)
        let byID = Dictionary(uniqueKeysWithValues: page.rows.map { ($0[0], $0[1]) })
        XCTAssertEqual(page.rowCount, 2)
        XCTAssertEqual(byID[.int(1)], .text("a2"))
        XCTAssertEqual(byID[.int(3)], .text("c"))
        XCTAssertNil(byID[.int(2)])
        XCTAssertFalse(staged.hasPendingChanges)
    }

    func testFailingStepRollsBackTheWholeBatch() async throws {
        let driver = try makeDriver()
        try await seed(driver)
        let staged = editor(driver)

        // Update id=1 (valid) then insert a duplicate primary key that fails at execution.
        _ = try staged.stageUpdate(row: ["id": .int(1), "name": .text("a")], column: "name", edit: .value("a2"))
        _ = staged.stageInsert(values: [ColumnValue(column: "id", value: .int(1)), ColumnValue(column: "name", value: .text("dup"))])

        do {
            try await staged.commit()
            XCTFail("expected the duplicate-key insert to abort the batch")
        } catch {
            // Expected: the whole transaction must roll back.
        }

        let page = try await driver.paginatedRows(database: schema, table: "t", limit: 10, offset: 0)
        let byID = Dictionary(uniqueKeysWithValues: page.rows.map { ($0[0], $0[1]) })
        XCTAssertEqual(page.rowCount, 2)
        XCTAssertEqual(byID[.int(1)], .text("a"))
    }

    func testStageDefaultResetsColumnToItsColumnDefault() async throws {
        let driver = try makeDriver()
        _ = try await driver.query("DROP DATABASE IF EXISTS \(schema)", database: nil)
        _ = try await driver.query("CREATE DATABASE \(schema)", database: nil)
        _ = try await driver.query(
            "CREATE TABLE \(schema).d (id INT PRIMARY KEY, status VARCHAR(20) NOT NULL DEFAULT 'active')",
            database: nil
        )
        _ = try await driver.query("INSERT INTO \(schema).d (id, status) VALUES (1, 'blocked')", database: nil)

        let staged = StagedTableEditor(
            schema: schema, table: "d", dialect: .forKind(.mysql),
            columns: [
                ColumnInfo(name: "id", dataType: "int", isNullable: false, isPrimaryKey: true),
                ColumnInfo(name: "status", dataType: "varchar(20)", isNullable: false, isPrimaryKey: false),
            ],
            driver: driver, database: schema
        )
        _ = try staged.stageUpdate(row: ["id": .int(1), "status": .text("blocked")], column: "status", edit: .default)
        try await staged.commit()

        let page = try await driver.paginatedRows(database: schema, table: "d", limit: 10, offset: 0)
        XCTAssertEqual(page.rows.first?[1], .text("active"))
    }
}
