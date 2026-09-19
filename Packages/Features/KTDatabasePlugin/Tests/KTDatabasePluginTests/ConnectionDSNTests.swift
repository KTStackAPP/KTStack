@testable import KTDatabasePlugin
import XCTest

final class ConnectionDSNTests: XCTestCase {
    func testMySQLURLWithEveryPart() throws {
        let draft = try ConnectionDSN.parse("mysql://root:secret@db.example.com:3307/shop")
        XCTAssertEqual(draft.profile.kind, .mysql)
        XCTAssertEqual(draft.profile.host, "db.example.com")
        XCTAssertEqual(draft.profile.port, 3307)
        XCTAssertEqual(draft.profile.user, "root")
        XCTAssertEqual(draft.profile.database, "shop")
        XCTAssertEqual(draft.profile.name, "shop")
        XCTAssertEqual(draft.password, "secret")
    }

    func testPostgresSchemesShareDefaultPort() throws {
        for scheme in ["postgres", "postgresql"] {
            let draft = try ConnectionDSN.parse("\(scheme)://app@127.0.0.1/app_db")
            XCTAssertEqual(draft.profile.kind, .postgres)
            XCTAssertEqual(draft.profile.port, 5432)
        }
    }

    func testMongoDefaultPort() throws {
        let draft = try ConnectionDSN.parse("mongodb://127.0.0.1/admin")
        XCTAssertEqual(draft.profile.kind, .mongodb)
        XCTAssertEqual(draft.profile.port, 27017)
        XCTAssertEqual(draft.profile.user, "")
    }

    func testPercentEncodedPasswordIsDecoded() throws {
        let draft = try ConnectionDSN.parse("mysql://root:p%40ss%3Aword@127.0.0.1:3306/app")
        XCTAssertEqual(draft.password, "p@ss:word")
    }

    func testNoDatabaseNamesFromUserAndHost() throws {
        let draft = try ConnectionDSN.parse("mysql://root@10.0.0.5:3306")
        XCTAssertEqual(draft.profile.database, "")
        XCTAssertEqual(draft.profile.name, "root@10.0.0.5")
    }

    func testEmptyPasswordBecomesNil() throws {
        let draft = try ConnectionDSN.parse("mysql://root@127.0.0.1/app")
        XCTAssertNil(draft.password)
    }

    func testUnknownSchemeThrows() {
        XCTAssertThrowsError(try ConnectionDSN.parse("redis://127.0.0.1:6379")) { error in
            XCTAssertEqual(error as? ConnectionDSNError, .unsupportedScheme("redis"))
        }
    }

    func testMongoSRVIsUnsupported() {
        XCTAssertThrowsError(try ConnectionDSN.parse("mongodb+srv://cluster.example.com/app")) { error in
            XCTAssertEqual(error as? ConnectionDSNError, .unsupportedScheme("mongodb+srv"))
        }
    }

    func testMissingHostThrows() {
        XCTAssertThrowsError(try ConnectionDSN.parse("mysql:///app")) { error in
            XCTAssertEqual(error as? ConnectionDSNError, .missingHost)
        }
    }

    func testEmptyInputThrowsMalformed() {
        XCTAssertThrowsError(try ConnectionDSN.parse("   ")) { error in
            XCTAssertEqual(error as? ConnectionDSNError, .malformed)
        }
    }

    func testTextWithoutSchemeThrowsMalformed() {
        XCTAssertThrowsError(try ConnectionDSN.parse("127.0.0.1:3306/app")) { error in
            XCTAssertEqual(error as? ConnectionDSNError, .malformed)
        }
    }
}
