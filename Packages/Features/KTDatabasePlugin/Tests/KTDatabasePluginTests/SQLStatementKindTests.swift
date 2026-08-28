import XCTest
@testable import KTDatabasePlugin

/// Engine-free tests for read/write classification used by the read-only gate.
final class SQLStatementKindTests: XCTestCase {
    func testReadStatements() {
        XCTAssertEqual(SQLStatementKind.classify("SELECT * FROM t"), .read)
        XCTAssertEqual(SQLStatementKind.classify("  with x as (select 1) select * from x"), .read)
        XCTAssertEqual(SQLStatementKind.classify("SHOW TABLES"), .read)
        XCTAssertEqual(SQLStatementKind.classify("EXPLAIN SELECT 1"), .read)
    }

    func testWriteStatements() {
        XCTAssertEqual(SQLStatementKind.classify("INSERT INTO t VALUES (1)"), .write)
        XCTAssertEqual(SQLStatementKind.classify("update t set a=1"), .write)
        XCTAssertEqual(SQLStatementKind.classify("DROP TABLE t"), .write)
        XCTAssertEqual(SQLStatementKind.classify("CREATE TABLE t (id int)"), .write)
    }

    func testDataModifyingCTEIsWrite() {
        XCTAssertEqual(
            SQLStatementKind.classify("WITH moved AS (DELETE FROM t RETURNING *) SELECT * FROM moved"),
            .write
        )
    }

    func testHasWriteScansEveryStatement() {
        XCTAssertTrue(SQLStatementKind.hasWrite("SELECT 1; DELETE FROM t WHERE id=1"))
        XCTAssertFalse(SQLStatementKind.hasWrite("SELECT 1; SELECT 2"))
    }
}
