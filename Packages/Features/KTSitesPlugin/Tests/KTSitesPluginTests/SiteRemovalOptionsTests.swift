import KTPlatformContracts
import XCTest
@testable import KTSitesPlugin

final class SiteRemovalOptionsTests: XCTestCase {
    func testDefaultsOnlyUnregister() {
        let options = SiteRemovalOptions()
        XCTAssertFalse(options.moveFolderToTrash)
        XCTAssertFalse(options.dropDatabase)
        let summary = SiteRemovalOptions.summary(makeSite(databaseName: "shop"), options: options)
        XCTAssertTrue(summary.contains("stays on disk"))
        XCTAssertTrue(summary.contains("is kept"))
        XCTAssertFalse(summary.contains("permanently"))
    }

    func testOptedInTrashAndDropAreSpelledOut() {
        let options = SiteRemovalOptions(moveFolderToTrash: true, dropDatabase: true)
        let summary = SiteRemovalOptions.summary(makeSite(path: "/sites/shop", databaseName: "shop"), options: options)
        XCTAssertTrue(summary.contains("/sites/shop moves to the Trash"))
        XCTAssertTrue(summary.contains("is dropped"))
    }

    func testProxySiteNeverOffersFolderTrash() {
        let proxy = makeSite(path: "", kind: .proxy, proxyTarget: "127.0.0.1:3000")
        XCTAssertFalse(SiteRemovalOptions.canTrashFolder(proxy))
        XCTAssertTrue(SiteRemovalOptions.summary(proxy, options: SiteRemovalOptions()).contains("127.0.0.1:3000"))
    }
}
