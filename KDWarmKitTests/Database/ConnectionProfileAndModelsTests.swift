import XCTest
@testable import KDWarmKit

/// Engine-free coverage of the Phase 2 model contracts: the `Cell` display mapping, `QueryResult`
/// column/row shape, and the `ConnectionProfile` Codable round-trip whose key invariant is that no
/// password ever reaches the JSON store.
final class ConnectionProfileAndModelsTests: XCTestCase {

    // MARK: - Cell

    func testCellDisplayTextDistinguishesNullFromEmptyText() {
        XCTAssertNil(Cell.null.displayText)            // NULL → no text (view styles a placeholder)
        XCTAssertEqual(Cell.text("").displayText, "")  // empty string stays distinct from NULL
        XCTAssertEqual(Cell.text("NULL").displayText, "NULL")
    }

    func testCellDisplayTextForScalars() {
        XCTAssertEqual(Cell.int(42).displayText, "42")
        XCTAssertEqual(Cell.bool(true).displayText, "1")
        XCTAssertEqual(Cell.bool(false).displayText, "0")
        XCTAssertEqual(Cell.blob(Data([0, 1, 2])).displayText, "[3 bytes]")
    }

    // MARK: - QueryResult

    func testQueryResultReportsColumnsIndependentlyOfRows() {
        let result = QueryResult(columns: [ColumnMeta(name: "a"), ColumnMeta(name: "b")], rows: [])
        XCTAssertEqual(result.columnNames, ["a", "b"])   // headers survive a zero-row result
        XCTAssertEqual(result.rowCount, 0)
    }

    // MARK: - ConnectionProfile Codable

    func testProfileCodableRoundTripPreservesFields() throws {
        let profile = ConnectionProfile(
            name: "prod-read", kind: .postgres, host: "db.example.com",
            port: 5432, user: "reader", database: "app", tlsMode: .verifyFull)
        let data = try JSONEncoder().encode(profile)
        let decoded = try JSONDecoder().decode(ConnectionProfile.self, from: data)
        XCTAssertEqual(decoded, profile)
    }

    func testEncodedProfileJSONNeverContainsAPasswordField() throws {
        let profile = ConnectionProfile(
            name: "x", kind: .mysql, host: "h", port: 3306, user: "u", database: "d")
        let json = String(decoding: try JSONEncoder().encode(profile), as: UTF8.self).lowercased()
        XCTAssertFalse(json.contains("password"))   // secrets live only in the Keychain, keyed by id
        XCTAssertFalse(json.contains("secret"))
    }

    // MARK: - TLS defaults

    func testTLSDefaultsToVerifyFullForRemoteAndPreferForLoopback() {
        let remote = ConnectionProfile(name: "r", kind: .mysql, host: "10.0.0.5",
                                       port: 3306, user: "u", database: "d")
        XCTAssertEqual(remote.tlsMode, .verifyFull)   // fails closed for non-loopback

        let local = ConnectionProfile(name: "l", kind: .mysql, host: "127.0.0.1",
                                      port: 3306, user: "u", database: "d")
        XCTAssertEqual(local.tlsMode, .prefer)
    }

    func testManagedProfileIsLoopbackRootAndFlaggedManaged() {
        let managed = ConnectionProfile.managedMySQL
        XCTAssertTrue(managed.isManaged)
        XCTAssertEqual(managed.host, "127.0.0.1")
        XCTAssertEqual(managed.user, "root")
        // A user-created profile with the same coordinates is NOT the managed one (id differs).
        let lookalike = ConnectionProfile(name: "x", kind: .mysql, host: "127.0.0.1",
                                          port: 3306, user: "root", database: "mysql")
        XCTAssertFalse(lookalike.isManaged)
    }
}
