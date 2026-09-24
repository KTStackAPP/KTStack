import XCTest
@testable import KTMailPlugin

final class MailStoreStateTests: XCTestCase {
    func testCancellationIsNotTreatedAsOutage() {
        XCTAssertTrue(MailStore.isCancellation(CancellationError()))
        XCTAssertTrue(MailStore.isCancellation(URLError(.cancelled)))
        XCTAssertFalse(MailStore.isCancellation(URLError(.cannotConnectToHost)))
    }

    @MainActor
    func testUnreachableMailpitSurfacesTheError() async {
        let store = MailStore(client: MailpitClient(baseURL: URL(string: "http://127.0.0.1:9")!))
        await store.refresh()
        XCTAssertFalse(store.isReachable)
        XCTAssertNotNil(store.lastError)
    }
}
