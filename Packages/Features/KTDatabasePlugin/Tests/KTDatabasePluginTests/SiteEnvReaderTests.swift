@testable import KTDatabasePlugin
import XCTest

final class SiteEnvReaderTests: XCTestCase {
    private var siteDir: URL!

    override func setUpWithError() throws {
        siteDir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("kt-site-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: siteDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: siteDir)
    }

    private func writeEnv(_ contents: String) throws {
        try contents.write(to: siteDir.appendingPathComponent(".env"), atomically: true, encoding: .utf8)
    }

    func testReadsLaravelStyleEnv() throws {
        try writeEnv("""
        # database
        APP_NAME=Shop
        DB_CONNECTION=mysql
        DB_HOST=127.0.0.1
        DB_PORT=3306
        DB_DATABASE="shop_db"
        DB_USERNAME='shop_user'
        export DB_PASSWORD=s3cret
        """)
        let draft = try SiteEnvReader.read(at: siteDir.path)
        XCTAssertEqual(draft.profile.kind, .mysql)
        XCTAssertEqual(draft.profile.host, "127.0.0.1")
        XCTAssertEqual(draft.profile.port, 3306)
        XCTAssertEqual(draft.profile.database, "shop_db")
        XCTAssertEqual(draft.profile.user, "shop_user")
        XCTAssertEqual(draft.profile.name, "shop_db")
        XCTAssertEqual(draft.password, "s3cret")
    }

    func testPgsqlMapsToPostgresWithDefaultPort() throws {
        try writeEnv("DB_CONNECTION=pgsql\nDB_DATABASE=app")
        let draft = try SiteEnvReader.read(at: siteDir.path)
        XCTAssertEqual(draft.profile.kind, .postgres)
        XCTAssertEqual(draft.profile.port, 5432)
        XCTAssertEqual(draft.profile.host, "127.0.0.1")
    }

    func testMariadbMapsToMySQL() throws {
        try writeEnv("DB_CONNECTION=mariadb\nDB_DATABASE=app")
        XCTAssertEqual(try SiteEnvReader.read(at: siteDir.path).profile.kind, .mysql)
    }

    func testMongodbMaps() throws {
        try writeEnv("DB_CONNECTION=mongodb\nDB_DATABASE=app")
        let draft = try SiteEnvReader.read(at: siteDir.path)
        XCTAssertEqual(draft.profile.kind, .mongodb)
        XCTAssertEqual(draft.profile.port, 27017)
    }

    func testNameFallsBackToSiteFolder() throws {
        try writeEnv("DB_HOST=127.0.0.1")
        let draft = try SiteEnvReader.read(at: siteDir.path)
        XCTAssertEqual(draft.profile.name, siteDir.lastPathComponent)
        XCTAssertNil(draft.password)
    }

    func testMissingFileThrows() {
        let empty = siteDir.appendingPathComponent("nope").path
        XCTAssertThrowsError(try SiteEnvReader.read(at: empty)) { error in
            XCTAssertEqual(error as? SiteEnvError, .fileMissing)
        }
    }

    func testEnvWithoutDatabaseKeysThrows() throws {
        try writeEnv("APP_NAME=Shop\n# DB_HOST=127.0.0.1\nAPP_ENV=local")
        XCTAssertThrowsError(try SiteEnvReader.read(at: siteDir.path)) { error in
            XCTAssertEqual(error as? SiteEnvError, .noDatabaseKeys)
        }
    }

    func testEmptyValuesFallBackToDefaults() throws {
        try writeEnv("DB_CONNECTION=mysql\nDB_HOST=\nDB_PORT=\nDB_PASSWORD=")
        let draft = try SiteEnvReader.read(at: siteDir.path)
        XCTAssertEqual(draft.profile.host, "127.0.0.1")
        XCTAssertEqual(draft.profile.port, 3306)
        XCTAssertNil(draft.password)
    }
}
