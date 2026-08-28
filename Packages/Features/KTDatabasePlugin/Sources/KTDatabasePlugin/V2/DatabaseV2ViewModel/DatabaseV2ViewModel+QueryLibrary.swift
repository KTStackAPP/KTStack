import Foundation

// Lịch sử, favorites, mở/lưu .sql và chọn DB cho từng query tab. Chỉ lưu văn bản SQL, không kèm mật khẩu kết nối.
public extension DatabaseV2ViewModel {
    func recordHistory(_ sql: String, database: String?) {
        try? historyStore.record(
            sql: sql,
            connectionLabel: connectionLabel ?? "Unknown connection",
            database: database
        )
        queryHistory = historyStore.entries()
    }

    func clearHistory() {
        try? historyStore.clear()
        queryHistory = historyStore.entries()
    }

    func saveFavorite(name: String) {
        let sql = queryText.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sql.isEmpty, !trimmedName.isEmpty else { return }
        try? favoriteStore.add(name: trimmedName, sql: sql)
        favorites = favoriteStore.entries()
    }

    func deleteFavorite(id: UUID) {
        try? favoriteStore.remove(id: id)
        favorites = favoriteStore.entries()
    }

    // Recall mở tab mới để không đè bản nháp đang soạn.
    func openInNewTab(title: String, text: String) {
        let tab = V2QueryTab(title: title, text: text)
        queryTabs.append(tab)
        activeQueryTabID = tab.id
        activeQuerySheet = nil
    }

    func recall(_ entry: QueryHistoryEntry) {
        openInNewTab(title: "History", text: entry.sql)
    }

    func recall(_ favorite: QueryFavorite) {
        openInNewTab(title: favorite.name, text: favorite.sql)
    }

    // nil = theo DB sidebar; ngược lại tab chạy trên DB được chỉ định.
    func setQueryDatabase(_ database: String?) {
        guard let id = activeQueryTab?.id,
              let index = queryTabs.firstIndex(where: { $0.id == id }) else { return }
        queryTabs[index].database = database
    }

    func loadSQLFile(name: String, text: String) {
        openInNewTab(title: name, text: text)
    }

    func showHistory() { activeQuerySheet = .history }
    func showFavorites() { activeQuerySheet = .favorites }
}
