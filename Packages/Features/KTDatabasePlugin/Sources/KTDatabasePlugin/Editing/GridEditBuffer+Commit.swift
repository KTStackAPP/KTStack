import Foundation

extension GridEditBuffer {
    struct CommitSnapshot {
        let state: State
        let version: Int
    }

    func commitSnapshot() -> CommitSnapshot {
        CommitSnapshot(state: state, version: version)
    }

    func markCommitted(_ snapshot: CommitSnapshot) {
        guard version != snapshot.version else {
            markCommitted()
            return
        }
        var remaining = state
        for (identity, columns) in snapshot.state.updates {
            for (column, value) in columns where remaining.updates[identity]?[column] == value {
                remaining.updates[identity]?[column] = nil
            }
            if remaining.updates[identity]?.isEmpty == true { remaining.updates[identity] = nil }
        }
        for (identity, columns) in snapshot.state.updateDefaults {
            remaining.updateDefaults[identity]?.subtract(columns)
            if remaining.updateDefaults[identity]?.isEmpty == true { remaining.updateDefaults[identity] = nil }
        }
        remaining.deletes.subtract(snapshot.state.deletes)
        let committedDrafts = Set(snapshot.state.inserts.map(\.id))
        remaining.inserts.removeAll { committedDrafts.contains($0.id) }
        state = remaining
        undoStack.removeAll()
        redoStack.removeAll()
        version += 1
    }
}
