import Foundation

/// One parameterized statement in a batch commit plus its guard. `expectedAffected` is the exact
/// row count the statement must touch (1 for a keyed insert/update/delete); `noOpKeyCheck` lets an
/// UPDATE that touches 0 rows prove the row still matches (unchanged value) versus went stale.
public struct WriteStep: Sendable, Equatable {
    public let statement: DMLStatement
    public let expectedAffected: Int
    public let noOpKeyCheck: DMLStatement?

    public init(statement: DMLStatement, expectedAffected: Int, noOpKeyCheck: DMLStatement? = nil) {
        self.statement = statement
        self.expectedAffected = expectedAffected
        self.noOpKeyCheck = noOpKeyCheck
    }
}
