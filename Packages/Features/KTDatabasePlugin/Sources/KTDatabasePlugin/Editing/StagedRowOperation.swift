import Foundation

/// Local id for a not-yet-inserted draft row, stable across edits until commit or discard.
public struct DraftRowID: Hashable, Sendable {
    public let value: Int

    public init(value: Int) {
        self.value = value
    }
}

/// One pending change ready for planning. Updates and deletes carry a `RowIdentity`; inserts carry
/// the draft's column values.
public enum StagedRowOperation: Sendable, Equatable {
    case insert(values: [ColumnValue])
    case update(identity: RowIdentity, changes: [ColumnValue])
    case delete(identity: RowIdentity)
}
