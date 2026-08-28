import XCTest
@testable import KTDatabasePlugin

final class GridColumnLayoutStoreTests: XCTestCase {
    private var fileURL: URL!

    override func setUpWithError() throws {
        fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("grid-layout-\(UUID().uuidString).json")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: fileURL)
    }

    private func identity(_ table: String = "users") -> TableIdentity {
        TableIdentity(profileID: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
                      database: "app", schema: "public", table: table)
    }

    func testSaveAndReloadPersistsAcrossInstances() throws {
        let store = GridColumnLayoutStore(fileURL: fileURL)
        try store.save([
            ColumnLayout(name: "id", isVisible: true, width: 60),
            ColumnLayout(name: "name", isVisible: false, width: 200),
        ], for: identity())

        let reopened = GridColumnLayoutStore(fileURL: fileURL)
        let layout = reopened.layout(for: identity())
        XCTAssertEqual(layout?.map(\.name), ["id", "name"])
        XCTAssertEqual(layout?[1].isVisible, false)
        XCTAssertEqual(layout?[0].width, 60)
    }

    func testLayoutIsolatedByTableIdentity() throws {
        let store = GridColumnLayoutStore(fileURL: fileURL)
        try store.save([ColumnLayout(name: "id")], for: identity("users"))
        XCTAssertNil(store.layout(for: identity("orders")))
    }

    func testReconciledKeepsStoredOrderDropsStaleAppendsNew() throws {
        let store = GridColumnLayoutStore(fileURL: fileURL)
        try store.save([
            ColumnLayout(name: "name", isVisible: false),
            ColumnLayout(name: "gone", isVisible: true),
            ColumnLayout(name: "id", isVisible: true),
        ], for: identity())

        let merged = store.reconciled(for: identity(), columns: ["id", "name", "email"])
        XCTAssertEqual(merged.map(\.name), ["name", "id", "email"])
        XCTAssertEqual(merged[0].isVisible, false)
        XCTAssertEqual(merged.last?.isVisible, true)
    }

    func testReconciledWithNoStoredLayoutReturnsAllVisible() {
        let store = GridColumnLayoutStore(fileURL: fileURL)
        let merged = store.reconciled(for: identity(), columns: ["a", "b"])
        XCTAssertEqual(merged.map(\.name), ["a", "b"])
        XCTAssertTrue(merged.allSatisfy(\.isVisible))
    }

    func testRemoveClearsLayout() throws {
        let store = GridColumnLayoutStore(fileURL: fileURL)
        try store.save([ColumnLayout(name: "id")], for: identity())
        try store.remove(for: identity())
        XCTAssertNil(store.layout(for: identity()))
    }
}
