import XCTest
@testable import KTDatabasePlugin

final class DriverCapabilitiesTests: XCTestCase {
    func testMySQLAdvertisesFullCapabilities() {
        let driver = MySQLDriver(profile: .managedMySQL, password: nil, tools: FakeDatabaseTools())
        XCTAssertEqual(driver.capabilities, DriverCapabilities())
    }

    func testPostgresAdvertisesFullCapabilities() {
        let driver = PostgresDriver(profile: .managedPostgres, password: nil, tools: FakeDatabaseTools())
        XCTAssertEqual(driver.capabilities, DriverCapabilities())
    }

    func testSQLiteAdvertisesNoQueryCancel() {
        let profile = ConnectionProfile(
            name: "SQLite", kind: .sqlite, host: "", port: 0, user: "", database: "main",
            filePath: "/tmp/ktstack-caps-test.sqlite"
        )
        let driver = SQLiteDriver(profile: profile)
        XCTAssertFalse(driver.capabilities.canCancelQueries)
        XCTAssertTrue(driver.capabilities.canEditRows)
        XCTAssertTrue(driver.capabilities.canEditSchema)
        XCTAssertTrue(driver.capabilities.canBrowsePaged)
    }

    func testNonePresetDisablesEverything() {
        XCTAssertFalse(DriverCapabilities.none.canBrowsePaged)
        XCTAssertFalse(DriverCapabilities.none.canEditRows)
        XCTAssertFalse(DriverCapabilities.none.canEditSchema)
        XCTAssertFalse(DriverCapabilities.none.canCancelQueries)
    }
}
