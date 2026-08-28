import Foundation

/// A parameterized, redacted view of the staged writes: statements keep placeholders, so it is safe
/// to show or copy without leaking literal values, and stays preview-only until the user commits.
public struct SQLPreview: Sendable, Equatable {
    public let statements: [String]
    public let bindCount: Int

    public init(statements: [String], bindCount: Int) {
        self.statements = statements
        self.bindCount = bindCount
    }
}

/// Turns staged operations into bound `WriteStep`s and a redacted `SQLPreview`. All values are
/// parameters; the dialect quotes identifiers and refuses a keyless UPDATE/DELETE.
public struct RelationalWritePlanner: Sendable {
    public let dialect: SQLDialect
    public let schema: String
    public let table: String

    public init(dialect: SQLDialect, schema: String, table: String) {
        self.dialect = dialect
        self.schema = schema
        self.table = table
    }

    public func plan(_ operations: [StagedRowOperation]) throws -> [WriteStep] {
        try operations.map { operation in
            switch operation {
            case let .insert(values):
                return WriteStep(
                    statement: try dialect.insert(schema: schema, table: table, values: values),
                    expectedAffected: 1
                )
            case let .update(identity, changes):
                return WriteStep(
                    statement: try dialect.update(schema: schema, table: table, values: changes, key: identity.key),
                    expectedAffected: 1,
                    noOpKeyCheck: try dialect.selectKeyExists(schema: schema, table: table, key: identity.key)
                )
            case let .delete(identity):
                return WriteStep(
                    statement: try dialect.delete(schema: schema, table: table, key: identity.key),
                    expectedAffected: 1
                )
            }
        }
    }

    public func preview(_ operations: [StagedRowOperation]) throws -> SQLPreview {
        let steps = try plan(operations)
        return SQLPreview(
            statements: steps.map { $0.statement.sql },
            bindCount: steps.reduce(0) { $0 + $1.statement.binds.count }
        )
    }
}
