import XCTest
@testable import KTDatabasePlugin

/// Engine-free coverage of typed-model DDL rendering, from MySQL/MariaDB public syntax. Identifiers
/// route through `quoteIdent`, types through `sanitizeType`, tokens through `sanitizeToken`, modeled
/// defaults/comments through `quoteString`, raw expressions through `sanitizeExpression`.
final class MySQLDDLRendererTests: XCTestCase {
    private let renderer = MySQLDDLRenderer(dialect: .forKind(.mysql), schema: "app")

    // MARK: - Column clauses

    func testPlainNullableColumn() throws {
        let sql = try renderer.columnClause(ColumnDraft(name: "age", type: "INT"))
        XCTAssertEqual(sql, "`age` INT")
    }

    func testNotNullColumn() throws {
        let sql = try renderer.columnClause(ColumnDraft(name: "email", type: "VARCHAR(255)", isNullable: false))
        XCTAssertEqual(sql, "`email` VARCHAR(255) NOT NULL")
    }

    func testAutoIncrementColumn() throws {
        let sql = try renderer.columnClause(
            ColumnDraft(name: "id", type: "INT", isNullable: false, isAutoIncrement: true)
        )
        XCTAssertEqual(sql, "`id` INT NOT NULL AUTO_INCREMENT")
    }

    func testDefaultKinds() throws {
        XCTAssertEqual(
            try renderer.columnClause(ColumnDraft(name: "c", type: "INT", defaultValue: .null)),
            "`c` INT DEFAULT NULL"
        )
        XCTAssertEqual(
            try renderer.columnClause(ColumnDraft(name: "c", type: "VARCHAR(10)", defaultValue: .text("hi"))),
            "`c` VARCHAR(10) DEFAULT 'hi'"
        )
        XCTAssertEqual(
            try renderer.columnClause(ColumnDraft(name: "c", type: "INT", defaultValue: .number("42"))),
            "`c` INT DEFAULT 42"
        )
        XCTAssertEqual(
            try renderer.columnClause(ColumnDraft(name: "c", type: "DATETIME", defaultValue: .currentTimestamp)),
            "`c` DATETIME DEFAULT CURRENT_TIMESTAMP"
        )
    }

    func testDefaultTextEscapesQuote() throws {
        let sql = try renderer.columnClause(ColumnDraft(name: "c", type: "VARCHAR(20)", defaultValue: .text("O'Brien")))
        XCTAssertEqual(sql, "`c` VARCHAR(20) DEFAULT 'O''Brien'")
    }

    func testCommentEscapes() throws {
        let sql = try renderer.columnClause(ColumnDraft(name: "c", type: "INT", comment: "it's fine"))
        XCTAssertEqual(sql, "`c` INT COMMENT 'it''s fine'")
    }

    func testCharsetAndCollation() throws {
        let sql = try renderer.columnClause(
            ColumnDraft(name: "c", type: "VARCHAR(10)", charset: "utf8mb4", collation: "utf8mb4_bin")
        )
        XCTAssertEqual(sql, "`c` VARCHAR(10) CHARACTER SET utf8mb4 COLLATE utf8mb4_bin")
    }

    func testExpressionDefault() throws {
        let sql = try renderer.columnClause(ColumnDraft(name: "uid", type: "CHAR(36)", defaultValue: .expression("uuid()")))
        XCTAssertEqual(sql, "`uid` CHAR(36) DEFAULT (uuid())")
    }

    func testOnUpdateCurrentTimestamp() throws {
        let sql = try renderer.columnClause(ColumnDraft(
            name: "updated_at", type: "TIMESTAMP", isNullable: false,
            defaultValue: .currentTimestamp, onUpdateCurrentTimestamp: true
        ))
        XCTAssertEqual(sql, "`updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP")
    }

    func testGeneratedColumnSkipsDefaultAndAutoIncrement() throws {
        let sql = try renderer.columnClause(ColumnDraft(
            name: "total",
            type: "INT",
            isAutoIncrement: true,
            defaultValue: .number("5"),
            generated: GeneratedColumn(expression: "`a` + `b`", kind: .stored)
        ))
        XCTAssertEqual(sql, "`total` INT GENERATED ALWAYS AS (`a` + `b`) STORED")
    }

    // MARK: - CREATE TABLE

    func testCreateTableWithEverything() throws {
        let draft = TableDefinitionDraft(
            name: "users",
            columns: [
                ColumnDraft(name: "id", type: "INT", isNullable: false, isAutoIncrement: true),
                ColumnDraft(name: "email", type: "VARCHAR(255)", isNullable: false),
                ColumnDraft(name: "bio", type: "TEXT", comment: "about"),
            ],
            primaryKey: ["id"],
            indexes: [IndexDraft(name: "idx_email", columns: ["email"], isUnique: true)],
            foreignKeys: [ForeignKeyDraft(
                name: "fk_org", columns: ["org_id"], refTable: "orgs", refColumns: ["id"],
                onDelete: .cascade, onUpdate: .restrict
            )],
            checks: [CheckConstraintDraft(name: "chk_email", expression: "email <> ''")],
            options: TableOptionDraft(engine: "InnoDB", charset: "utf8mb4")
        )
        let statement = try renderer.renderCreateTable(draft)
        XCTAssertEqual(
            statement.sql,
            "CREATE TABLE `app`.`users` (`id` INT NOT NULL AUTO_INCREMENT, "
                + "`email` VARCHAR(255) NOT NULL, `bio` TEXT COMMENT 'about', "
                + "PRIMARY KEY (`id`), UNIQUE INDEX `idx_email` (`email`), "
                + "CONSTRAINT `fk_org` FOREIGN KEY (`org_id`) REFERENCES `app`.`orgs` (`id`) "
                + "ON DELETE CASCADE ON UPDATE RESTRICT, "
                + "CONSTRAINT `chk_email` CHECK (email <> '')) "
                + "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4"
        )
        XCTAssertFalse(statement.isDestructive)
    }

    func testCreateTableCompositePrimaryKeyForcesNotNull() throws {
        let draft = TableDefinitionDraft(
            name: "grant",
            columns: [
                ColumnDraft(name: "host", type: "VARCHAR(60)"),
                ColumnDraft(name: "user", type: "VARCHAR(32)"),
            ],
            primaryKey: ["host", "user"]
        )
        let statement = try renderer.renderCreateTable(draft)
        XCTAssertEqual(
            statement.sql,
            "CREATE TABLE `app`.`grant` (`host` VARCHAR(60) NOT NULL, `user` VARCHAR(32) NOT NULL, "
                + "PRIMARY KEY (`host`, `user`))"
        )
    }

    func testCreateTableRejectsEmptyColumns() {
        XCTAssertThrowsError(try renderer.renderCreateTable(TableDefinitionDraft(name: "t")))
    }

    // MARK: - ALTER changes

    func testAddColumnWithPosition() throws {
        let statement = try renderer.render(
            .addColumn(ColumnDraft(name: "mid", type: "INT"), after: "id"),
            table: "t"
        )
        XCTAssertEqual(statement.sql, "ALTER TABLE `app`.`t` ADD COLUMN `mid` INT AFTER `id`")
        XCTAssertFalse(statement.isDestructive)
    }

    func testModifyColumnRenames() throws {
        let statement = try renderer.render(
            .modifyColumn(original: "old", ColumnDraft(name: "new", type: "BIGINT", isNullable: false)),
            table: "t"
        )
        XCTAssertEqual(statement.sql, "ALTER TABLE `app`.`t` CHANGE COLUMN `old` `new` BIGINT NOT NULL")
        XCTAssertEqual(statement.summary, "Rename column `old` to `new`")
    }

    func testDropColumnIsDestructive() throws {
        let statement = try renderer.render(.dropColumn("x"), table: "t")
        XCTAssertEqual(statement.sql, "ALTER TABLE `app`.`t` DROP COLUMN `x`")
        XCTAssertTrue(statement.isDestructive)
    }

    func testPrimaryKeyChanges() throws {
        XCTAssertEqual(
            try renderer.render(.setPrimaryKey(["a", "b"]), table: "t").sql,
            "ALTER TABLE `app`.`t` ADD PRIMARY KEY (`a`, `b`)"
        )
        let drop = try renderer.render(.dropPrimaryKey, table: "t")
        XCTAssertEqual(drop.sql, "ALTER TABLE `app`.`t` DROP PRIMARY KEY")
        XCTAssertTrue(drop.isDestructive)
    }

    func testIndexChanges() throws {
        XCTAssertEqual(
            try renderer.render(.addIndex(IndexDraft(name: "idx", columns: ["a", "b"])), table: "t").sql,
            "ALTER TABLE `app`.`t` ADD INDEX `idx` (`a`, `b`)"
        )
        XCTAssertEqual(
            try renderer.render(.addIndex(IndexDraft(name: "", columns: ["a"], isUnique: true)), table: "t").sql,
            "ALTER TABLE `app`.`t` ADD UNIQUE INDEX (`a`)"
        )
        let drop = try renderer.render(.dropIndex("idx"), table: "t")
        XCTAssertEqual(drop.sql, "ALTER TABLE `app`.`t` DROP INDEX `idx`")
        XCTAssertTrue(drop.isDestructive)
    }

    func testForeignKeyChanges() throws {
        let add = try renderer.render(.addForeignKey(ForeignKeyDraft(
            name: "fk", columns: ["a"], refTable: "ref", refColumns: ["id"],
            onDelete: .setNull, onUpdate: .cascade
        )), table: "t")
        XCTAssertEqual(
            add.sql,
            "ALTER TABLE `app`.`t` ADD CONSTRAINT `fk` FOREIGN KEY (`a`) "
                + "REFERENCES `app`.`ref` (`id`) ON DELETE SET NULL ON UPDATE CASCADE"
        )
        let drop = try renderer.render(.dropForeignKey("fk"), table: "t")
        XCTAssertEqual(drop.sql, "ALTER TABLE `app`.`t` DROP FOREIGN KEY `fk`")
        XCTAssertTrue(drop.isDestructive)
    }

    func testCheckChanges() throws {
        XCTAssertEqual(
            try renderer.render(.addCheck(CheckConstraintDraft(name: "chk", expression: "age >= 0")), table: "t").sql,
            "ALTER TABLE `app`.`t` ADD CONSTRAINT `chk` CHECK (age >= 0)"
        )
        let drop = try renderer.render(.dropCheck("chk"), table: "t")
        XCTAssertEqual(drop.sql, "ALTER TABLE `app`.`t` DROP CONSTRAINT `chk`")
        XCTAssertTrue(drop.isDestructive)
    }

    func testTableOptions() throws {
        let statement = try renderer.render(
            .setTableOptions(TableOptionDraft(engine: "InnoDB", autoIncrement: 100, comment: "hi")),
            table: "t"
        )
        XCTAssertEqual(statement.sql, "ALTER TABLE `app`.`t` ENGINE=InnoDB AUTO_INCREMENT=100 COMMENT='hi'")
    }

    // MARK: - Injection and validation

    func testColumnNameInjectionNeutralized() throws {
        let sql = try renderer.columnClause(ColumnDraft(name: "a`b", type: "INT"))
        XCTAssertEqual(sql, "`a``b` INT")
    }

    func testTypeInjectionRejected() {
        XCTAssertThrowsError(try renderer.columnClause(ColumnDraft(name: "c", type: "INT; DROP TABLE x")))
    }

    func testCharsetTokenInjectionRejected() {
        XCTAssertThrowsError(
            try renderer.columnClause(ColumnDraft(name: "c", type: "VARCHAR(10)", charset: "utf8 OR 1=1"))
        )
    }

    func testGeneratedExpressionTerminatorRejected() {
        XCTAssertThrowsError(try renderer.columnClause(ColumnDraft(
            name: "c", type: "INT", generated: GeneratedColumn(expression: "1; DROP TABLE x", kind: .virtual)
        )))
    }

    func testCheckExpressionTerminatorRejected() {
        XCTAssertThrowsError(
            try renderer.render(.addCheck(CheckConstraintDraft(name: "c", expression: "1=1; DROP TABLE x")), table: "t")
        )
    }

    func testNumericDefaultInjectionRejected() {
        XCTAssertThrowsError(
            try renderer.columnClause(ColumnDraft(name: "c", type: "INT", defaultValue: .number("0 OR 1=1")))
        )
    }
}
