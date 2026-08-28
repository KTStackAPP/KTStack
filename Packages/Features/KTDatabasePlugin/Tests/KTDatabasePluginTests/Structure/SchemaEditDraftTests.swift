import XCTest
@testable import KTDatabasePlugin

/// The diff engine: server metadata in, ordered `[SchemaChange]` out. Drops precede adds; the
/// primary key drops before column edits and re-adds after them.
final class SchemaEditDraftTests: XCTestCase {
    private func baseDraft() -> SchemaEditDraft {
        SchemaEditDraft(
            tableName: "users",
            columns: [
                ColumnInfo(name: "id", dataType: "int", isNullable: false, isPrimaryKey: true),
                ColumnInfo(name: "name", dataType: "varchar(255)", isNullable: true, isPrimaryKey: false),
            ],
            indexes: [
                IndexInfo(name: "PRIMARY", columns: ["id"], isUnique: true),
                IndexInfo(name: "idx_name", columns: ["name"], isUnique: false),
            ]
        )
    }

    func testNoEditsProducesNoChanges() {
        XCTAssertTrue(baseDraft().changes().isEmpty)
        XCTAssertFalse(baseDraft().hasChanges)
    }

    func testAddColumn() {
        var draft = baseDraft()
        draft.columns.append(ColumnDraft(name: "age", type: "INT"))
        XCTAssertEqual(tags(draft.changes()), ["addColumn(age)"])
    }

    func testDropColumn() {
        var draft = baseDraft()
        draft.columns.removeAll { $0.name == "name" }
        XCTAssertEqual(tags(draft.changes()), ["dropColumn(name)"])
    }

    func testModifyColumnType() {
        var draft = baseDraft()
        draft.columns[1].type = "TEXT"
        XCTAssertEqual(tags(draft.changes()), ["modifyColumn(name)"])
    }

    func testRenameColumnKeepsOriginal() {
        var draft = baseDraft()
        draft.columns[1].name = "full_name"
        XCTAssertEqual(tags(draft.changes()), ["modifyColumn(name)"])
    }

    func testAddIndex() {
        var draft = baseDraft()
        draft.indexes.append(IndexDraft(name: "idx_age", columns: ["age"]))
        XCTAssertEqual(tags(draft.changes()), ["addIndex(idx_age)"])
    }

    func testDropIndex() {
        var draft = baseDraft()
        draft.indexes.removeAll { $0.name == "idx_name" }
        XCTAssertEqual(tags(draft.changes()), ["dropIndex(idx_name)"])
    }

    func testModifyIndexDropsThenAdds() {
        var draft = baseDraft()
        draft.indexes[0].isUnique = true
        XCTAssertEqual(tags(draft.changes()), ["dropIndex(idx_name)", "addIndex(idx_name)"])
    }

    func testPrimaryKeyChangeDropsThenSets() {
        var draft = baseDraft()
        draft.primaryKey = ["id", "name"]
        XCTAssertEqual(tags(draft.changes()), ["dropPrimaryKey", "setPrimaryKey"])
    }

    func testForeignKeyAndCheckLists() {
        var draft = baseDraft()
        draft.addedForeignKeys.append(ForeignKeyDraft(
            name: "fk", columns: ["name"], refTable: "orgs", refColumns: ["id"]
        ))
        draft.droppedForeignKeys.append("fk_old")
        draft.addedChecks.append(CheckConstraintDraft(name: "chk", expression: "id > 0"))
        draft.droppedChecks.append("chk_old")
        XCTAssertEqual(
            tags(draft.changes()),
            ["dropForeignKey(fk_old)", "dropCheck(chk_old)", "addForeignKey(fk)", "addCheck(chk)"]
        )
    }

    func testTableOptions() {
        var draft = baseDraft()
        draft.tableOptions.comment = "hi"
        XCTAssertEqual(tags(draft.changes()), ["setTableOptions"])
    }

    // Drops before adds: FK drop, index drop, PK drop, column drop, then modify/add, then PK set/options.
    func testOrderingDropsBeforeAdds() {
        var draft = baseDraft()
        draft.droppedForeignKeys.append("fk_old")
        draft.indexes.removeAll { $0.name == "idx_name" }
        draft.primaryKey = ["name"]
        draft.columns.removeAll { $0.name == "name" }
        draft.columns.append(ColumnDraft(name: "age", type: "INT"))
        draft.tableOptions.engine = "InnoDB"
        let result = tags(draft.changes())
        XCTAssertEqual(result.first, "dropForeignKey(fk_old)")
        XCTAssertLessThan(index(of: "dropPrimaryKey", result), index(of: "setPrimaryKey", result))
        XCTAssertLessThan(index(of: "dropColumn(name)", result), index(of: "addColumn(age)", result))
        XCTAssertEqual(result.last, "setTableOptions")
    }

    func testMapDefaultHeuristics() {
        XCTAssertEqual(SchemaEditDraft.mapDefault(nil, generated: false), .none)
        XCTAssertEqual(SchemaEditDraft.mapDefault("42", generated: false), .number("42"))
        XCTAssertEqual(SchemaEditDraft.mapDefault("CURRENT_TIMESTAMP", generated: false), .currentTimestamp)
        XCTAssertEqual(SchemaEditDraft.mapDefault("hello", generated: false), .text("hello"))
        XCTAssertEqual(SchemaEditDraft.mapDefault("5", generated: true), .none)
        XCTAssertEqual(SchemaEditDraft.mapDefault("uuid()", generated: false, isExpression: true), .expression("uuid()"))
    }

    // Sửa comment của cột có ON UPDATE + expression default vẫn giữ nguyên cả hai (chống H1).
    func testModifyColumnPreservesOnUpdateAndExpressionDefault() {
        var draft = SchemaEditDraft(
            tableName: "t",
            columns: [
                ColumnInfo(name: "id", dataType: "int", isNullable: false, isPrimaryKey: true),
                ColumnInfo(
                    name: "updated_at", dataType: "timestamp", isNullable: false, isPrimaryKey: false,
                    defaultValue: "CURRENT_TIMESTAMP", onUpdateCurrentTimestamp: true
                ),
            ],
            indexes: [IndexInfo(name: "PRIMARY", columns: ["id"], isUnique: true)]
        )
        draft.columns[1].comment = "edited"
        let changes = draft.changes()
        XCTAssertEqual(tags(changes), ["modifyColumn(updated_at)"])
        guard case let .modifyColumn(_, column) = changes[0] else { return XCTFail("expected modifyColumn") }
        let sql = try? MySQLDDLRenderer(dialect: .forKind(.mysql), schema: "app")
            .render(.modifyColumn(original: "updated_at", column), table: "t").sql
        XCTAssertEqual(
            sql,
            "ALTER TABLE `app`.`t` CHANGE COLUMN `updated_at` `updated_at` timestamp NOT NULL "
                + "DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP COMMENT 'edited'"
        )
    }

    // MARK: - Helpers

    private func index(of tag: String, _ list: [String]) -> Int {
        list.firstIndex(of: tag) ?? -1
    }

    private func tags(_ changes: [SchemaChange]) -> [String] {
        changes.map { change in
            switch change {
            case let .addColumn(column, _): "addColumn(\(column.name))"
            case let .modifyColumn(original, _): "modifyColumn(\(original))"
            case let .dropColumn(name): "dropColumn(\(name))"
            case .setPrimaryKey: "setPrimaryKey"
            case .dropPrimaryKey: "dropPrimaryKey"
            case let .addIndex(index): "addIndex(\(index.name))"
            case let .dropIndex(name): "dropIndex(\(name))"
            case let .addForeignKey(fk): "addForeignKey(\(fk.name))"
            case let .dropForeignKey(name): "dropForeignKey(\(name))"
            case let .addCheck(check): "addCheck(\(check.name))"
            case let .dropCheck(name): "dropCheck(\(name))"
            case .setTableOptions: "setTableOptions"
            }
        }
    }
}
