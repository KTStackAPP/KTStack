import XCTest
@testable import KTDatabasePlugin

final class RowIdentityResolverTests: XCTestCase {
    private func column(_ name: String, pk: Bool = false, nullable: Bool = true) -> ColumnInfo {
        ColumnInfo(name: name, dataType: "int", isNullable: nullable, isPrimaryKey: pk)
    }

    func testPrimaryKeyIdentity() {
        let resolver = RowIdentityResolver(columns: [column("id", pk: true), column("name")])
        let identity = resolver.identity(for: ["id": .int(7), "name": .text("a")])
        XCTAssertEqual(identity?.source, .primaryKey)
        XCTAssertEqual(identity?.key, [ColumnValue(column: "id", value: .int(7))])
    }

    func testCompositePrimaryKeyKeepsColumnOrder() {
        let resolver = RowIdentityResolver(columns: [column("a", pk: true), column("b", pk: true)])
        let identity = resolver.identity(for: ["b": .int(2), "a": .int(1)])
        XCTAssertEqual(identity?.key.map(\.column), ["a", "b"])
    }

    func testFallsBackToNonNullUniqueKey() {
        let resolver = RowIdentityResolver(
            columns: [column("email"), column("name")],
            uniqueIndexes: [IndexInfo(name: "uq_email", columns: ["email"], isUnique: true)]
        )
        let identity = resolver.identity(for: ["email": .text("x@y.z"), "name": .text("a")])
        XCTAssertEqual(identity?.source, .uniqueKey("uq_email"))
        XCTAssertEqual(identity?.key, [ColumnValue(column: "email", value: .text("x@y.z"))])
    }

    func testPrimaryKeyWinsOverUniqueKey() {
        let resolver = RowIdentityResolver(
            columns: [column("id", pk: true), column("email")],
            uniqueIndexes: [IndexInfo(name: "uq_email", columns: ["email"], isUnique: true)]
        )
        XCTAssertEqual(resolver.identity(for: ["id": .int(1), "email": .text("a")])?.source, .primaryKey)
    }

    func testNullInKeyIsRejected() {
        let resolver = RowIdentityResolver(columns: [column("id", pk: true)])
        XCTAssertNil(resolver.identity(for: ["id": .null]))
    }

    func testNonUniqueIndexIsIgnored() {
        let resolver = RowIdentityResolver(
            columns: [column("name")],
            uniqueIndexes: [IndexInfo(name: "idx_name", columns: ["name"], isUnique: false)]
        )
        XCTAssertNil(resolver.identity(for: ["name": .text("a")]))
    }

    func testKeylessRowHasNoIdentity() {
        let resolver = RowIdentityResolver(columns: [column("name"), column("note")])
        XCTAssertNil(resolver.identity(for: ["name": .text("a"), "note": .text("b")]))
    }

    func testMissingKeyColumnHasNoIdentity() {
        let resolver = RowIdentityResolver(columns: [column("id", pk: true)])
        XCTAssertNil(resolver.identity(for: ["name": .text("a")]))
    }
}
