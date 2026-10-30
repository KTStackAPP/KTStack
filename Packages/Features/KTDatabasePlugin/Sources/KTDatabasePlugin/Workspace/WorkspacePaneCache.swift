import Foundation

/// Thứ tự dùng gần nhất của pane tab đang giữ sống, trả về id cần bỏ khi vượt giới hạn.
struct WorkspacePaneCache {
    let limit: Int
    private(set) var order: [UUID] = []

    init(limit: Int) {
        self.limit = max(1, limit)
    }

    mutating func retain(_ liveIDs: Set<UUID>) -> [UUID] {
        let gone = order.filter { !liveIDs.contains($0) }
        order.removeAll { !liveIDs.contains($0) }
        return gone
    }

    mutating func touch(_ id: UUID) -> [UUID] {
        order.removeAll { $0 == id }
        order.append(id)
        guard order.count > limit else { return [] }
        let evicted = Array(order.prefix(order.count - limit))
        order.removeFirst(evicted.count)
        return evicted
    }
}
