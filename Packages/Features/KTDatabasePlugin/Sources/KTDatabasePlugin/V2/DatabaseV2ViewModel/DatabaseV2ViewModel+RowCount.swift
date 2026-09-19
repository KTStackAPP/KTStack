import Foundation

public extension DatabaseV2ViewModel {
    // Ước lượng tổng số dòng bằng COUNT(*) chạy nền sau trang đầu; huỷ khi bảng/lọc đổi.
    func refreshRowCount() {
        rowCountTask?.cancel()
        rowCountEstimate = nil
        guard let driver, let database = selectedDatabase, let table = selectedTable else {
            isCountingRows = false
            return
        }
        let filters = activeFilters
        let kind = connectionKind ?? .mysql
        let token = generation
        isCountingRows = true
        rowCountTask = Task { [weak self] in
            let statement = try? SQLDialect.forKind(kind).countSelect(
                schema: database, table: table.name, filters: filters
            )
            guard let statement else {
                await MainActor.run { self?.finishRowCount(nil, token: token) }
                return
            }
            let result = try? await driver.runSelect(statement, database: database)
            if Task.isCancelled { return }
            let count = result?.rows.first?.first.flatMap(Self.intValue)
            await MainActor.run { self?.finishRowCount(count, token: token) }
        }
    }

    internal func fetchServerVersion(driver: RelationalDriver, token: Int) {
        Task { [weak self] in
            guard let version = try? await driver.serverVersion() else { return }
            await MainActor.run {
                guard let self, self.generation == token, !version.isEmpty else { return }
                self.serverVersion = version
            }
        }
    }

    private func finishRowCount(_ count: Int?, token: Int) {
        guard token == generation else { return }
        isCountingRows = false
        rowCountEstimate = count
    }

    private static func intValue(_ cell: Cell) -> Int? {
        switch cell {
        case let .int(n): Int(n)
        case let .double(d): Int(d)
        case let .text(s): Int(s)
        default: nil
        }
    }
}
