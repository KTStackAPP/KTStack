import Foundation

extension DatabaseV2ViewModel {
    var hasUnsavedEdits: Bool {
        pendingChangeCount > 0 || insertDraft != nil
    }

    public func commitStaged() async {
        guard !isCommitting, let editor = staged, editor.hasPendingChanges else { return }
        isCommitting = true
        defer { isCommitting = false }
        await ensureConnected()
        let token = generation
        editError = nil
        do {
            try await editor.commit()
            guard token == generation else { return }
            await reloadLoaded()
            refreshStagedState()
        } catch {
            guard token == generation else { return }
            editError = error.localizedDescription
        }
    }

    func keepsPendingEditor() -> Bool {
        guard let staged, staged.hasPendingChanges, let table = selectedTable,
              staged.table == table.name,
              staged.columns.map(\.name) == columns.map(\.name)
        else { return false }
        refreshStagedState()
        return true
    }

    func resetStagingUnlessEditing(_ table: TableInfo) {
        guard staged?.table != table.name else { return }
        staged = nil
        insertDraft = nil
        refreshStagedState()
    }

    func allowLeavingStagedTable(for target: TableInfo) -> Bool {
        guard hasUnsavedEdits, target.name != selectedTable?.name else { return true }
        editError = "Commit or discard \(unsavedEditsLabel) before leaving \(selectedTable?.name ?? "this table")."
        return false
    }

    func ddlAllowed() -> Bool {
        guard canApplySchema else {
            ddlError = "This connection is read-only."
            return false
        }
        guard !hasUnsavedEdits else {
            ddlError = "Commit or discard \(unsavedEditsLabel) before changing the table structure."
            return false
        }
        return true
    }

    private var unsavedEditsLabel: String {
        pendingChangeCount > 0 ? "\(pendingChangeCount) pending row change(s)" : "the new row draft"
    }
}
