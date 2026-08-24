import Combine
import Foundation

// Rule M10 (design mục 8): platform expose command + state stream. Dựng AsyncStream snapshot từ
// objectWillChange. objectWillChange fire TRƯỚC mutation; AsyncPublisher deliver bất đồng bộ nên khi
// loop resume mutation đã xong, đọc make() ra giá trị mới. Bỏ trùng bằng Equatable. Mẫu cho M11.
extension ObservableObject where ObjectWillChangePublisher == ObservableObjectPublisher {
    @MainActor
    func snapshotStream<S: Equatable & Sendable>(_ make: @escaping @MainActor () -> S) -> AsyncStream<S> {
        AsyncStream { continuation in
            let task = Task { @MainActor [weak self] in
                guard let self else { return }
                var last = make()
                continuation.yield(last)
                for await _ in self.objectWillChange.values {
                    let next = make()
                    guard next != last else { continue }
                    last = next
                    continuation.yield(next)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
