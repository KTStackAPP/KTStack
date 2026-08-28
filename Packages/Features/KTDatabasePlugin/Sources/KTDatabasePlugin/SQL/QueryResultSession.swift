import Foundation

// Một kết quả trong phiên chạy: câu lệnh nguồn (để Fetch All chạy lại không cap), lưới hoặc lỗi, cờ ghim/cap.
public struct QueryResultItem: Identifiable, Equatable {
    public let id: UUID
    public var label: String
    public var statement: String
    public var binds: [Cell]
    public var result: QueryResult?
    public var error: String?
    public var notice: String?
    public var isPinned: Bool
    public var capApplied: Bool
    public var isFetchingAll: Bool

    public init(
        id: UUID = UUID(),
        label: String,
        statement: String,
        binds: [Cell] = [],
        result: QueryResult? = nil,
        error: String? = nil,
        notice: String? = nil,
        isPinned: Bool = false,
        capApplied: Bool = false,
        isFetchingAll: Bool = false
    ) {
        self.id = id
        self.label = label
        self.statement = statement
        self.binds = binds
        self.result = result
        self.error = error
        self.notice = notice
        self.isPinned = isPinned
        self.capApplied = capApplied
        self.isFetchingAll = isFetchingAll
    }

    public var isTruncatedByCap: Bool {
        capApplied && (result?.truncated ?? false)
    }
}

// Các kết quả có thứ tự của một tab query. Kết quả ghim sống qua lần chạy sau; kết quả không ghim bị thay.
public struct QueryResultSession: Equatable {
    public var items: [QueryResultItem]
    public var activeItemID: UUID?

    public init(items: [QueryResultItem] = [], activeItemID: UUID? = nil) {
        self.items = items
        self.activeItemID = activeItemID
    }

    public static let empty = QueryResultSession()

    public var activeItem: QueryResultItem? {
        guard let activeItemID else { return items.first }
        return items.first { $0.id == activeItemID } ?? items.first
    }

    // Bắt đầu lần chạy mới: giữ kết quả đã ghim, bỏ phần còn lại.
    public mutating func beginRun() {
        items = items.filter(\.isPinned)
        activeItemID = nil
    }

    public mutating func append(_ item: QueryResultItem) {
        items.append(item)
        if activeItemID == nil { activeItemID = item.id }
    }

    public mutating func select(_ id: UUID) {
        guard items.contains(where: { $0.id == id }) else { return }
        activeItemID = id
    }

    public mutating func togglePin(_ id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].isPinned.toggle()
    }

    public mutating func close(_ id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        let wasActive = activeItemID == id
        items.remove(at: index)
        if wasActive {
            activeItemID = items.indices.contains(index)
                ? items[index].id
                : items.last?.id
        }
    }

    public mutating func update(_ id: UUID, mutate: (inout QueryResultItem) -> Void) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        mutate(&items[index])
    }
}
