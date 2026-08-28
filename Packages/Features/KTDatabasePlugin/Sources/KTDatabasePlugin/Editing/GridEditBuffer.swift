import Foundation

/// Holds pending data edits outside any AppKit view: per-row updates, staged deletes and draft
/// inserts, plus an undo/redo history. Snapshots the whole staged state per change so undo/redo
/// stay correct without per-operation inverses; the state is small (only pending edits, not data).
public final class GridEditBuffer {
    private struct DraftRow: Equatable {
        let id: DraftRowID
        var values: [String: Cell]
    }

    private struct State: Equatable {
        var updates: [RowIdentity: [String: Cell]] = [:]
        var deletes: Set<RowIdentity> = []
        var inserts: [DraftRow] = []

        var isEmpty: Bool {
            updates.isEmpty && deletes.isEmpty && inserts.isEmpty
        }
    }

    private var state = State()
    private var undoStack: [State] = []
    private var redoStack: [State] = []
    private var draftCounter = 0

    public init() {}

    public var hasPendingChanges: Bool { !state.isEmpty }

    public var pendingCount: Int {
        state.updates.count + state.deletes.count + state.inserts.count
    }

    public func stagedUpdate(for identity: RowIdentity) -> [String: Cell]? {
        state.updates[identity]
    }

    public func isStagedDelete(_ identity: RowIdentity) -> Bool {
        state.deletes.contains(identity)
    }

    public var canUndo: Bool { !undoStack.isEmpty }
    public var canRedo: Bool { !redoStack.isEmpty }

    public func stageUpdate(identity: RowIdentity, column: String, value: Cell) {
        apply { working in
            guard !working.deletes.contains(identity) else { return }
            working.updates[identity, default: [:]][column] = value
        }
    }

    public func clearUpdate(identity: RowIdentity) {
        apply { $0.updates[identity] = nil }
    }

    @discardableResult
    public func stageInsert() -> DraftRowID {
        draftCounter += 1
        let id = DraftRowID(value: draftCounter)
        apply { $0.inserts.append(DraftRow(id: id, values: [:])) }
        return id
    }

    public func setDraftValue(_ id: DraftRowID, column: String, value: Cell) {
        apply { working in
            guard let idx = working.inserts.firstIndex(where: { $0.id == id }) else { return }
            working.inserts[idx].values[column] = value
        }
    }

    public func removeDraft(_ id: DraftRowID) {
        apply { working in working.inserts.removeAll { $0.id == id } }
    }

    public func stageDelete(identity: RowIdentity) {
        apply { working in
            working.updates[identity] = nil // xóa thắng: bỏ update đang chờ của cùng hàng
            working.deletes.insert(identity)
        }
    }

    public func unstageDelete(identity: RowIdentity) {
        apply { $0.deletes.remove(identity) }
    }

    public func undo() {
        guard let previous = undoStack.popLast() else { return }
        redoStack.append(state)
        state = previous
    }

    public func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(state)
        state = next
    }

    public func discardAll() {
        guard !state.isEmpty else { return }
        undoStack.append(state)
        redoStack.removeAll()
        state = State()
    }

    // Sau commit, staged đã thành sự thật: xóa cả undo/redo (thay đổi đã commit không nằm trong undo).
    public func markCommitted() {
        state = State()
        undoStack.removeAll()
        redoStack.removeAll()
    }

    /// Deterministic commit order: deletes free key slots first, then updates, then inserts.
    public func operations() -> [StagedRowOperation] {
        var ops: [StagedRowOperation] = []
        for identity in state.deletes.sorted(by: { $0.signature < $1.signature }) {
            ops.append(.delete(identity: identity))
        }
        for (identity, changes) in state.updates.sorted(by: { $0.key.signature < $1.key.signature }) {
            guard !changes.isEmpty else { continue }
            ops.append(.update(identity: identity, changes: columnValues(changes)))
        }
        for draft in state.inserts where !draft.values.isEmpty {
            ops.append(.insert(values: columnValues(draft.values)))
        }
        return ops
    }

    private func columnValues(_ map: [String: Cell]) -> [ColumnValue] {
        map.keys.sorted().map { ColumnValue(column: $0, value: map[$0]!) }
    }

    private func apply(_ change: (inout State) -> Void) {
        var next = state
        change(&next)
        guard next != state else { return }
        undoStack.append(state)
        redoStack.removeAll()
        state = next
    }
}
