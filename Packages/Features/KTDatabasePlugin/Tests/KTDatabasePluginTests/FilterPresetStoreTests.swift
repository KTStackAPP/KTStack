import XCTest
@testable import KTDatabasePlugin

@MainActor
final class FilterPresetStoreTests: XCTestCase {
    private func tempURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("kt-filter-presets-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent("filter-presets.json")
    }

    func testSavePersistsAndReloadsAcrossInstances() {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        let store = FilterPresetStore(storeURL: url)
        let preset = FilterPreset(
            name: "active",
            conditions: [FilterCondition(column: "status", op: .equals, value: .text("active"))]
        )
        store.save(preset, database: "shop", table: "users")

        let reloaded = FilterPresetStore(storeURL: url)
        let presets = reloaded.presets(database: "shop", table: "users")
        XCTAssertEqual(presets, [preset])
    }

    func testPresetsAreScopedByDatabaseAndTable() {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        let store = FilterPresetStore(storeURL: url)
        store.save(FilterPreset(name: "a", conditions: [FilterCondition(column: "x", op: .isNull)]),
                   database: "shop", table: "users")

        XCTAssertEqual(store.presets(database: "shop", table: "users").count, 1)
        XCTAssertTrue(store.presets(database: "shop", table: "orders").isEmpty)
        XCTAssertTrue(store.presets(database: "other", table: "users").isEmpty)
    }

    func testSaveWithSameNameReplaces() {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        let store = FilterPresetStore(storeURL: url)
        store.save(FilterPreset(name: "p", conditions: [FilterCondition(column: "x", op: .equals, value: .int(1))]),
                   database: "d", table: "t")
        store.save(FilterPreset(name: "p", conditions: [FilterCondition(column: "y", op: .equals, value: .int(2))]),
                   database: "d", table: "t")

        let presets = store.presets(database: "d", table: "t")
        XCTAssertEqual(presets.count, 1)
        XCTAssertEqual(presets.first?.conditions.first?.column, "y")
    }

    func testRemoveDeletesAndPersists() {
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        let store = FilterPresetStore(storeURL: url)
        store.save(FilterPreset(name: "p", conditions: [FilterCondition(column: "x", op: .isNotNull)]),
                   database: "d", table: "t")
        store.remove(name: "p", database: "d", table: "t")

        XCTAssertTrue(store.presets(database: "d", table: "t").isEmpty)
        XCTAssertTrue(FilterPresetStore(storeURL: url).presets(database: "d", table: "t").isEmpty)
    }

    func testFilterPresetCodableRoundTripAcrossCellKinds() throws {
        let preset = FilterPreset(name: "mixed", conditions: [
            FilterCondition(column: "a", op: .equals, value: .text("hi")),
            FilterCondition(column: "b", op: .greaterThan, value: .int(5)),
            FilterCondition(column: "c", op: .lessThan, value: .double(1.5)),
            FilterCondition(column: "d", op: .equals, value: .bool(true)),
            FilterCondition(column: "e", op: .isNull, value: .null),
            FilterCondition(column: "f", op: .equals, value: .blob(Data([0x01, 0x02])))
        ])
        let data = try JSONEncoder().encode(preset)
        let decoded = try JSONDecoder().decode(FilterPreset.self, from: data)
        XCTAssertEqual(decoded, preset)
    }
}
