import KTStackCore
import XCTest

final class AppURLRouteTests: XCTestCase {
    private func route(_ string: String) -> AppURLRoute {
        AppURLRoute(URL(string: string)!)
    }

    func testDatabaseHost() {
        XCTAssertEqual(route("ktstack://database"), .database(profileID: nil))
    }

    func testDatabaseWithProfile() {
        let id = UUID()
        XCTAssertEqual(route("ktstack://database?profile=\(id.uuidString)"), .database(profileID: id))
    }

    func testDatabaseWithInvalidProfileDropsID() {
        XCTAssertEqual(route("ktstack://database?profile=not-a-uuid"), .database(profileID: nil))
    }

    func testSchemelessPathForm() {
        XCTAssertEqual(route("ktstack:database"), .database(profileID: nil))
    }

    func testUnknownScheme() {
        XCTAssertEqual(route("https://database"), .unknown)
    }

    func testUnknownHost() {
        XCTAssertEqual(route("ktstack://settings"), .unknown)
    }
}
