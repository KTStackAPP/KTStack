import KTStackCore
import XCTest
@testable import KTStackKit

final class SQLFamilyTests: XCTestCase {
    func testKindsAreThe3306Family() {
        XCTAssertEqual(SQLFamily.kinds, [.mysql, .mariadb])
    }

    func testOtherPairsMySQLAndMariaDB() {
        XCTAssertEqual(SQLFamily.other(.mysql), .mariadb)
        XCTAssertEqual(SQLFamily.other(.mariadb), .mysql)
    }

    func testOtherIsNilOutsideTheFamily() {
        XCTAssertNil(SQLFamily.other(.postgres))
        XCTAssertNil(SQLFamily.other(.redis))
        XCTAssertNil(SQLFamily.other(.memcached))
        XCTAssertNil(SQLFamily.other(.mongodb))
    }
}
