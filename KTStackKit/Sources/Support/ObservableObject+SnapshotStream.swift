import Combine
import Foundation

// Rule M10 (design mục 8): platform expose command + state stream. Dựng AsyncStream snapshot từ
// objectWillChange. KHÔNG dùng `objectWillChange.values` (Combine AsyncPublisher assert-crash khi
// publisher gửi nhiều value trước khi async consumer kịp pull, ví dụ progress download bắn dồn).
// Thay bằng `sink` đồng bộ đẩy tick vào AsyncStream (bufferingNewest coalesce), consumer chạy @MainActor
// resume SAU mutation nên make() đọc giá trị mới; bỏ trùng bằng Equatable. Mẫu cho M11.
extension ObservableObject where ObjectWillChangePublisher == ObservableObjectPublisher {
    @MainActor
    func snapshotStream<S: Equatable & Sendable>(_ make: @escaping @MainActor () -> S) -> AsyncStream<S> {
        AsyncStream { continuation in
            let (ticks, tickContinuation) = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
            let cancellable = objectWillChange.sink { _ in tickContinuation.yield(()) }
            let task = Task { @MainActor in
                var last = make()
                continuation.yield(last)
                for await _ in ticks {
                    let next = make()
                    guard next != last else { continue }
                    last = next
                    continuation.yield(next)
                }
            }
            continuation.onTermination = { _ in
                cancellable.cancel()
                tickContinuation.finish()
                task.cancel()
            }
        }
    }
}
