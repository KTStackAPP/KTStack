import Foundation

public extension DatabaseV2ViewModel {
    var savedPresets: [FilterPreset] {
        guard let presetStore, let database = selectedDatabase, let table = selectedTable else { return [] }
        return presetStore.presets(database: database, table: table.name)
    }

    func saveCurrentFiltersAsPreset(name: String) {
        savePreset(name: name, conditions: activeFilters)
    }

    func savePreset(name: String, conditions: [FilterCondition]) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !conditions.isEmpty,
              let presetStore, let database = selectedDatabase, let table = selectedTable else { return }
        presetStore.save(
            FilterPreset(name: trimmed, conditions: conditions), database: database, table: table.name
        )
        objectWillChange.send()
    }

    func applyPreset(_ preset: FilterPreset) {
        applyFilters(preset.conditions)
    }

    func deletePreset(_ preset: FilterPreset) {
        guard let presetStore, let database = selectedDatabase, let table = selectedTable else { return }
        presetStore.remove(name: preset.name, database: database, table: table.name)
        objectWillChange.send()
    }
}
