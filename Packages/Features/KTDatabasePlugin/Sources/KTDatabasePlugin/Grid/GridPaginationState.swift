import Foundation

public enum RowCountEstimate: Equatable, Sendable {
    case unknown
    case exact(Int)
    case estimated(Int)

    public var value: Int? {
        switch self {
        case .unknown: nil
        case let .exact(count), let .estimated(count): count
        }
    }
}

/// Zero-based page cursor plus size and known/estimated total. All navigation clamps; `next` past an
/// unknown total is allowed (a short page proves the end), past a known total is capped.
public struct GridPaginationState: Equatable, Sendable {
    public private(set) var pageSize: Int
    public private(set) var page: Int
    public var total: RowCountEstimate

    public init(pageSize: Int = 100, page: Int = 0, total: RowCountEstimate = .unknown) {
        self.pageSize = max(1, pageSize)
        self.page = max(0, page)
        self.total = total
    }

    public var offset: Int {
        page * pageSize
    }

    public var pageCount: Int? {
        guard let count = total.value else { return nil }
        guard count > 0 else { return 1 }
        return Int((Double(count) / Double(pageSize)).rounded(.up))
    }

    public var hasPrevious: Bool {
        page > 0
    }

    public var hasNext: Bool {
        guard let count = pageCount else { return true }
        return page + 1 < count
    }

    public mutating func setPageSize(_ size: Int) {
        pageSize = max(1, size)
        page = 0
    }

    public mutating func first() {
        page = 0
    }

    public mutating func previous() {
        if page > 0 { page -= 1 }
    }

    public mutating func next() {
        if hasNext { page += 1 }
    }

    public mutating func last() {
        if let count = pageCount { page = count - 1 }
    }
}
