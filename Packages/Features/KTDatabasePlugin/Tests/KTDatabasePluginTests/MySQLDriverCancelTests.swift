import KTPlatformContracts
import KTStackCore
import XCTest
@testable import KTDatabasePlugin

/// Opt-in proof that Cancel stops a running server query fast and leaves the session reusable. Gated on
/// `KTSTACK_DB_IT=1` + a managed MySQL/MariaDB on :3306, so a clean CI box skips. Cancel issues
/// `KILL QUERY` over a short-lived control connection, so `SELECT SLEEP(30)` stops within a second and
/// the persistent session keeps serving the next query.
final class MySQLDriverCancelTests: XCTestCase {

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

    func testCancelStopsSleepWithinOneSecond() async throws {
        let driver = try makeDriver()
        try await driver.openSession()
        let start = Date()
        async let running: QueryResult = driver.query("SELECT SLEEP(30)", database: nil)
        try await Task.sleep(for: .milliseconds(300))
        await driver.cancelCurrentQuery()
        do {
            _ = try await running
            XCTFail("expected the cancelled query to throw")
        } catch let error as DatabaseError {
            XCTAssertEqual(error, .cancelled)
        }
        XCTAssertLessThan(Date().timeIntervalSince(start), 1.0, "cancel must stop SLEEP(30) within 1s")

        // Session còn sống: query kế tiếp chạy bình thường trên cùng connection.
        let next = try await driver.query("SELECT 7 AS v", database: nil)
        XCTAssertEqual(next.rows.first?.first, .int(7))
        await driver.closeSession()
    }
}
