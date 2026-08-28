import Foundation

// Yêu cầu nhập giá trị cho các placeholder :name trước khi chạy; giá trị nhập ở dạng chuỗi, coerce khi bind.
public struct QueryParameterPrompt: Identifiable, Equatable {
    public let id: UUID
    public let names: [String]

    public init(id: UUID = UUID(), names: [String]) {
        self.id = id
        self.names = names
    }
}

public enum V2QuerySheet: String, Identifiable {
    case history
    case favorites

    public var id: String { rawValue }
}

// Xác nhận trước khi chạy câu phá hủy (DROP/TRUNCATE, DELETE/UPDATE thiếu WHERE).
public struct DestructivePrompt: Identifiable, Equatable {
    public let id: UUID
    public let reason: String

    public init(id: UUID = UUID(), reason: String) {
        self.id = id
        self.reason = reason
    }
}

// Kết quả EXPLAIN: cây khi phân tích được, ngược lại lưới thô; error khi engine từ chối.
public struct ExplainResult: Identifiable {
    public let id: UUID
    public let tree: [ExplainNode]?
    public let raw: QueryResult?
    public let error: String?

    public init(id: UUID = UUID(), tree: [ExplainNode]? = nil, raw: QueryResult? = nil, error: String? = nil) {
        self.id = id
        self.tree = tree
        self.raw = raw
        self.error = error
    }
}

public struct V2QueryTab: Identifiable, Equatable {
    public let id: UUID
    public var title: String
    public var text: String
    public var database: String?
    public var session: QueryResultSession
    public var isRunning: Bool

    public init(
        id: UUID = UUID(),
        title: String,
        text: String = "",
        database: String? = nil,
        session: QueryResultSession = .empty,
        isRunning: Bool = false
    ) {
        self.id = id
        self.title = title
        self.text = text
        self.database = database
        self.session = session
        self.isRunning = isRunning
    }

    public var result: QueryResult? { session.activeItem?.result }
    public var error: String? { session.activeItem?.error }
}

public extension DatabaseV2ViewModel {
    var activeQueryTab: V2QueryTab? {
        guard let activeQueryTabID else { return queryTabs.first }
        return queryTabs.first { $0.id == activeQueryTabID } ?? queryTabs.first
    }

    var queryText: String {
        get { activeQueryTab?.text ?? "" }
        set {
            guard let id = activeQueryTab?.id,
                  let idx = queryTabs.firstIndex(where: { $0.id == id }) else { return }
            queryTabs[idx].text = newValue
        }
    }

    var querySession: QueryResultSession { activeQueryTab?.session ?? .empty }

    var queryResults: [QueryResultItem] { querySession.items }

    var activeQueryResult: QueryResultItem? { querySession.activeItem }

    var queryResult: QueryResult? { activeQueryResult?.result }

    var queryError: String? { activeQueryResult?.error }

    var isRunning: Bool { activeQueryTab?.isRunning ?? false }

    // DB đích của tab hiện tại; nil dùng DB đang chọn ở sidebar.
    var activeQueryDatabase: String? { activeQueryTab?.database ?? selectedDatabase }

    func addQueryTab() {
        let tab = V2QueryTab(title: "Query \(queryTabs.count + 1)")
        queryTabs.append(tab)
        activeQueryTabID = tab.id
    }

    func closeQueryTab(id: UUID) {
        guard queryTabs.count > 1 else { return }
        guard let index = queryTabs.firstIndex(where: { $0.id == id }) else { return }
        let wasActive = activeQueryTabID == id
        queryTabs.remove(at: index)
        if wasActive {
            activeQueryTabID = queryTabs[min(index, queryTabs.count - 1)].id
        }
    }

    func selectQueryTab(id: UUID) {
        guard queryTabs.contains(where: { $0.id == id }) else { return }
        activeQueryTabID = id
    }

    func runQuery() async {
        guard activeQueryTab != nil else { return }
        let sql = queryText
        if connectionReadOnly, SQLStatementKind.hasWrite(sql) {
            showBlocked("This connection is read-only. Write statements are blocked.", sql: sql)
            return
        }
        let verdict = DestructiveGuard.evaluate(sql)
        if verdict.isDestructive {
            destructivePrompt = DestructivePrompt(reason: verdict.reason ?? "This statement changes or removes data.")
            return
        }
        await promptOrRun()
    }

    func confirmDestructiveRun() async {
        destructivePrompt = nil
        await promptOrRun()
    }

    func cancelDestructiveRun() {
        destructivePrompt = nil
    }

    private func promptOrRun() async {
        let names = QueryParameterBinder.placeholders(in: queryText)
        if !names.isEmpty {
            parameterPrompt = QueryParameterPrompt(names: names)
            return
        }
        await executeRun(values: [:])
    }

    func submitParameters(_ raw: [String: String]) async {
        parameterPrompt = nil
        await executeRun(values: raw.mapValues(QueryParameterBinder.coerce))
    }

    func cancelParameterPrompt() {
        parameterPrompt = nil
    }

    private func showBlocked(_ message: String, sql: String) {
        guard let tabID = activeQueryTab?.id else { return }
        mutateQueryTab(tabID) { t in
            t.session.beginRun()
            t.session.append(QueryResultItem(label: "Blocked", statement: sql, error: message))
        }
    }

    // Chạy EXPLAIN cho câu đầu; cây nếu phân tích được, ngược lại lưới thô.
    func explainActiveQuery() async {
        guard let driver, let tab = activeQueryTab else { return }
        guard let first = SQLStatementSplitter.statements(tab.text).first else { return }
        let database = tab.database ?? selectedDatabase
        let sql = explainSQL(for: first, kind: connectionKind ?? .mysql)
        do {
            let raw = try await driver.query(sql, database: database)
            explainSheet = ExplainResult(tree: ExplainPlanParser.parse(raw), raw: raw)
        } catch {
            let dbError = (error as? DatabaseError) ?? .connection(error.localizedDescription)
            explainSheet = ExplainResult(error: dbError.message)
        }
    }

    private func explainSQL(for statement: String, kind: DatabaseKind) -> String {
        switch kind {
        case .mysql: "EXPLAIN FORMAT=TREE \(statement)"
        default: "EXPLAIN \(statement)"
        }
    }

    // Editor tự áp format qua NSTextView để Cmd-Z hoàn tác một bước; đây chỉ báo hiệu.
    func requestFormat() {
        formatTrigger &+= 1
    }

    private func executeRun(values: [String: Cell]) async {
        guard let driver, let tab = activeQueryTab else { return }
        let tabID = tab.id
        let database = tab.database ?? selectedDatabase
        let statements = SQLStatementSplitter.split(tab.text)
        guard !statements.isEmpty else { return }
        let dialect = SQLDialect.forKind(connectionKind ?? .mysql)

        mutateQueryTab(tabID) { t in
            t.isRunning = true
            t.session.beginRun()
        }
        recordHistory(tab.text, database: database)

        var index = pinnedCount(tabID)
        for statement in statements {
            index += 1
            let item = await runStatement(
                statement.sql, label: "Result \(index)", values: values,
                dialect: dialect, database: database, driver: driver
            )
            mutateQueryTab(tabID) { $0.session.append(item) }
            if item.error != nil { break }
        }
        mutateQueryTab(tabID) { $0.isRunning = false }
    }

    private func runStatement(
        _ sql: String,
        label: String,
        values: [String: Cell],
        dialect: SQLDialect,
        database: String?,
        driver: RelationalDriver
    ) async -> QueryResultItem {
        do {
            if QueryParameterBinder.hasPlaceholders(sql) {
                let bound = QueryParameterBinder.bind(sql, values: values, dialect: dialect).statement
                let limited = SQLAutoLimit.augment(bound.sql, dialect: dialect)
                let raw = try await driver.runSelect(
                    DMLStatement(sql: limited.sql, binds: bound.binds), database: database
                )
                let result = capped(raw, applied: limited.applied)
                return QueryResultItem(
                    label: label, statement: bound.sql, binds: bound.binds, result: result,
                    notice: result.columns.isEmpty ? "Statement executed" : nil, capApplied: limited.applied
                )
            }
            let limited = SQLAutoLimit.augment(sql, dialect: dialect)
            let raw = try await driver.query(limited.sql, database: database)
            let result = capped(raw, applied: limited.applied)
            return QueryResultItem(
                label: label, statement: sql, result: result,
                notice: result.columns.isEmpty ? "Statement executed" : nil, capApplied: limited.applied
            )
        } catch {
            let dbError = (error as? DatabaseError) ?? .connection(error.localizedDescription)
            let cancelled = dbError == .cancelled
            return QueryResultItem(
                label: label, statement: sql,
                error: cancelled ? nil : dbError.message, notice: cancelled ? dbError.message : nil
            )
        }
    }

    // Chạy lại đúng câu lệnh của một kết quả bị cap, không auto-limit.
    func fetchAll(resultID: UUID) async {
        guard let driver, let tab = activeQueryTab else { return }
        let tabID = tab.id
        guard let item = tab.session.items.first(where: { $0.id == resultID }), item.capApplied else { return }
        let database = tab.database ?? selectedDatabase
        mutateQueryTab(tabID) { t in
            t.isRunning = true
            t.session.update(resultID) { $0.isFetchingAll = true }
        }
        do {
            let raw = item.binds.isEmpty
                ? try await driver.query(item.statement, database: database)
                : try await driver.runSelect(
                    DMLStatement(sql: item.statement, binds: item.binds), database: database
                )
            mutateQueryTab(tabID) { t in
                t.session.update(resultID) { r in
                    r.result = raw
                    r.error = nil
                    r.notice = raw.columns.isEmpty ? "Statement executed" : nil
                    r.capApplied = false
                    r.isFetchingAll = false
                }
            }
        } catch {
            let dbError = (error as? DatabaseError) ?? .connection(error.localizedDescription)
            let cancelled = dbError == .cancelled
            mutateQueryTab(tabID) { t in
                t.session.update(resultID) { r in
                    r.isFetchingAll = false
                    if !cancelled { r.error = dbError.message; r.result = nil }
                    else { r.notice = dbError.message }
                }
            }
        }
        mutateQueryTab(tabID) { $0.isRunning = false }
    }

    func selectResult(id: UUID) {
        guard let tabID = activeQueryTab?.id else { return }
        mutateQueryTab(tabID) { $0.session.select(id) }
    }

    func togglePinResult(id: UUID) {
        guard let tabID = activeQueryTab?.id else { return }
        mutateQueryTab(tabID) { $0.session.togglePin(id) }
    }

    func closeResult(id: UUID) {
        guard let tabID = activeQueryTab?.id else { return }
        mutateQueryTab(tabID) { $0.session.close(id) }
    }

    func cancelQuery() async {
        await driver?.cancelCurrentQuery()
        guard let id = activeQueryTab?.id,
              let idx = queryTabs.firstIndex(where: { $0.id == id }) else { return }
        queryTabs[idx].isRunning = false
    }

    private func pinnedCount(_ id: UUID) -> Int {
        queryTabs.first { $0.id == id }?.session.items.filter(\.isPinned).count ?? 0
    }

    private func capped(_ raw: QueryResult, applied: Bool) -> QueryResult {
        guard applied else { return raw }
        return QueryResult(
            columns: raw.columns,
            rows: raw.rows,
            truncated: raw.rowCount >= SQLAutoLimit.defaultMax,
            estimatedTotal: raw.estimatedTotal
        )
    }

    private func mutateQueryTab(_ id: UUID, mutate: (inout V2QueryTab) -> Void) {
        guard let index = queryTabs.firstIndex(where: { $0.id == id }) else { return }
        mutate(&queryTabs[index])
    }
}
