import XCTest
@testable import KTDatabasePlugin

final class GridFilterModelTests: XCTestCase {
    private let mysql = SQLDialect.forKind(.mysql)

    func testAddUpdateRemove() {
        var model = GridFilterModel()
        model.add(FilterCondition(column: "a", op: .equals, value: .int(1)))
        model.add(FilterCondition(column: "b", op: .isNull))
        XCTAssertEqual(model.conditions.count, 2)
        model.update(at: 0, to: FilterCondition(column: "a", op: .greaterThan, value: .int(5)))
        XCTAssertEqual(model.conditions[0].op, .greaterThan)
        model.remove(at: 1)
        XCTAssertEqual(model.conditions.count, 1)
        model.remove(at: 9)
        XCTAssertEqual(model.conditions.count, 1)
    }

    func testSavePresetRoundtrip() {
        var model = GridFilterModel()
        model.add(FilterCondition(column: "status", op: .equals, value: .text("paid")))
        model.savePreset(name: "paid")
        model.clear()
        XCTAssertTrue(model.isEmpty)
        model.applyPreset("paid")
        XCTAssertEqual(model.conditions.first?.column, "status")
    }

    func testSavePresetOverwritesSameName() {
        var model = GridFilterModel()
        model.add(FilterCondition(column: "a", op: .isNull))
        model.savePreset(name: "p")
        model.clear()
        model.add(FilterCondition(column: "b", op: .isNotNull))
        model.savePreset(name: "p")
        XCTAssertEqual(model.presets.count, 1)
        XCTAssertEqual(model.presets.first?.conditions.first?.column, "b")
    }

    func testBlankPresetNameIgnored() {
        var model = GridFilterModel()
        model.savePreset(name: "   ")
        XCTAssertTrue(model.presets.isEmpty)
    }

    func testPreviewIsPlaceholdersOnlyNeverLiterals() throws {
        var model = GridFilterModel()
        model.add(FilterCondition(column: "name", op: .equals, value: .text("secret")))
        model.add(FilterCondition(column: "age", op: .isNotNull))
        let preview = try model.previewWhere(dialect: mysql)
        XCTAssertEqual(preview, "`name` = ? AND `age` IS NOT NULL")
        XCTAssertFalse(preview?.contains("secret") ?? true)
    }

    func testPreviewNilWhenNoConditions() throws {
        let model = GridFilterModel()
        XCTAssertNil(try model.previewWhere(dialect: mysql))
    }
}
