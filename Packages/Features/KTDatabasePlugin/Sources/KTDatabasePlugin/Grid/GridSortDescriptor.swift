import Foundation

/// Multi-column sort. Click order is priority: the first cycled column sorts first.
/// Cycling one column steps none -> ascending -> descending -> removed.
public struct GridSortDescriptor: Equatable, Sendable {
    public private(set) var specs: [SortSpec]

    public init(specs: [SortSpec] = []) {
        self.specs = specs
    }

    public mutating func cycle(_ column: String) {
        guard let index = specs.firstIndex(where: { $0.column == column }) else {
            specs.append(SortSpec(column: column, ascending: true))
            return
        }
        if specs[index].ascending {
            specs[index] = SortSpec(column: column, ascending: false)
        } else {
            specs.remove(at: index)
        }
    }

    public func direction(for column: String) -> Bool? {
        specs.first { $0.column == column }?.ascending
    }

    public func priority(of column: String) -> Int? {
        specs.firstIndex { $0.column == column }
    }

    public mutating func clear() {
        specs.removeAll()
    }

    public var isEmpty: Bool {
        specs.isEmpty
    }
}
