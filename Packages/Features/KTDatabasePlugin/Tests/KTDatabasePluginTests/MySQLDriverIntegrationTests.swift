import KTPlatformContracts
import KTStackCore
import XCTest
@testable import KTDatabasePlugin

/// Opt-in integration coverage for `MySQLDriver` against the managed engine. Gated on `KTSTACK_DB_IT=1`
/// AND an installed engine, so a clean CI box (no engine) skips rather than fails. The engine must be
/// running on :3306. Proves the driver returns real schema + query results and that the NIO→result
/// path is safe under rapid concurrent re-query (stressing the NIO→@MainActor result boundary).
final class MySQLDriverIntegrationTests: XCTestCase {

    private var opened: [MySQLDriver] = []

    override func tearDown() async throws {
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

    func testPingSucceeds() async throws {
        let driver = try makeDriver()
        try await driver.ping()
    }

    func testListDatabasesIncludesSystemSchemas() async throws {
        let driver = try makeDriver()
        let names = try await driver.listDatabases().map(\.name)
        XCTAssertTrue(names.contains("mysql"))
        XCTAssertTrue(names.contains("information_schema"))
    }

    func testCompositePrimaryKeyIntrospection() async throws {
        // Engine-neutral: MariaDB's mysql.user is a keyless VIEW, so build our own composite-PK table
        // and prove introspection reports both key columns (the case the row-edit phase relies on).
        let driver = try makeDriver()
        let suffix = UUID().uuidString.prefix(8)
        let db = "kt_pk_\(suffix)"
        _ = try await driver.query("CREATE DATABASE \(db)", database: nil)
        _ = try await driver.query(
            "CREATE TABLE \(db).t (a INT NOT NULL, b INT NOT NULL, note VARCHAR(16), PRIMARY KEY (a, b))",
            database: nil
        )

        let tables = try await driver.listTables(database: db).map(\.name)
        XCTAssertTrue(tables.contains("t"))

        let columns = try await driver.columns(database: db, table: "t")
        XCTAssertFalse(columns.isEmpty)
        XCTAssertEqual(Set(columns.primaryKeyColumns.map(\.name)), ["a", "b"])

        _ = try? await driver.query("DROP DATABASE IF EXISTS \(db)", database: nil)
    }

    func testQueryMapsTypedCellsAndNull() async throws {
        let driver = try makeDriver()
        // 1.5e0 is a DOUBLE literal; a bare 1.5 is DECIMAL, which the mapper keeps as text to preserve
        // precision. Cover both so the double vs decimal distinction stays asserted.
        let result = try await driver.query("SELECT 1 AS i, 1.5e0 AS d, 1.5 AS dnum, NULL AS n, 'x' AS s", database: nil)
        XCTAssertEqual(result.columnNames, ["i", "d", "dnum", "n", "s"])
        XCTAssertEqual(result.rows.count, 1)
        XCTAssertEqual(result.rows[0][0], .int(1))
        XCTAssertEqual(result.rows[0][1], .double(1.5))
        XCTAssertEqual(result.rows[0][2], .text("1.5"))
        XCTAssertEqual(result.rows[0][3], .null)
        XCTAssertEqual(result.rows[0][4], .text("x"))
    }

    func testZeroRowQueryPreservesColumns() async throws {
        let driver = try makeDriver()
        let result = try await driver.query("SELECT 1 AS a, 2 AS b WHERE 1 = 0", database: nil)
        XCTAssertEqual(result.columnNames, ["a", "b"])
        XCTAssertEqual(result.rowCount, 0)
    }

    func testPaginationLimitsRows() async throws {
        let driver = try makeDriver()
        let page = try await driver.paginatedRows(
            database: "information_schema",
            table: "COLUMNS",
            limit: 5,
            offset: 0
        )
        XCTAssertLessThanOrEqual(page.rowCount, 5)
        XCTAssertFalse(page.columns.isEmpty)
    }

    /// Rapid concurrent re-query: every call opens its own connection on the shared event-loop group,
    /// resolves NIO futures internally, and returns a Sendable result. Nothing here touches @MainActor
    /// state, so 20 overlapping queries must all complete without a crash or a data race.
    func testConcurrentQueriesAreRaceFree() async throws {
        let driver = try makeDriver()
        try await withThrowingTaskGroup(of: Int.self) { group in
            for _ in 0..<20 {
                group.addTask {
                    let result = try await driver.query("SELECT 1 AS n", database: nil)
                    return result.rowCount
                }
            }
            var total = 0
            for try await count in group {
                total += count
            }
            XCTAssertEqual(total, 20)
        }
    }
}
