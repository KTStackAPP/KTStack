import XCTest
@testable import KTDatabasePlugin

final class DriverCapabilitiesTests: XCTestCase {
    func testMySQLAdvertisesFullCapabilities() {
        let driver = MySQLDriver(profile: .managedMySQL, password: nil, tools: FakeDatabaseTools())
        XCTAssertEqual(driver.capabilities, DriverCapabilities())
    }

    func testPostgresDoesNotAdvertiseSchemaEditing() {
        let driver = PostgresDriver(profile: .managedPostgres, password: nil, tools: FakeDatabaseTools())
        XCTAssertEqual(driver.capabilities, DriverCapabilities(canEditSchema: false))
    }

    func testSQLiteAdvertisesNoQueryCancel() {
        let profile = ConnectionProfile(
            name: "SQLite", kind: .sqlite, host: "", port: 0, user: "", database: "main",
            filePath: "/tmp/ktstack-caps-test.sqlite"
        )
        let driver = SQLiteDriver(profile: profile)
        XCTAssertFalse(driver.capabilities.canCancelQueries)
        XCTAssertTrue(driver.capabilities.canEditRows)
        XCTAssertFalse(driver.capabilities.canEditSchema, "the schema editor emits MySQL DDL")
        XCTAssertTrue(driver.capabilities.canBrowsePaged)
    }

    func testNonePresetDisablesEverything() {
        XCTAssertFalse(DriverCapabilities.none.canBrowsePaged)
        XCTAssertFalse(DriverCapabilities.none.canEditRows)
        XCTAssertFalse(DriverCapabilities.none.canEditSchema)
        XCTAssertFalse(DriverCapabilities.none.canCancelQueries)
    }
}
