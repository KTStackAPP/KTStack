import Foundation
import KTPluginKit

// Gọi lifecycle của plugin. Thứ tự giữa các plugin độc lập (mỗi plugin chỉ đụng resource riêng).
// standalone = plugin không vào sidebar (headless, ví dụ Tunnel) nhưng vẫn có lifecycle.
@MainActor
final class PluginLifecycleCoordinator {
    private let lifecycles: [any PluginLifecycle]

    init(plugins: [any KTStackPlugin], standalone: [any PluginLifecycle] = []) {
        lifecycles = plugins.compactMap { $0 as? any PluginLifecycle } + standalone
    }

    func startAll() {
        for plugin in lifecycles {
            Task.detached { await plugin.start() }
        }
    }

    // Block main tối đa `timeout` (plugin shutdown là file ops nhanh); vượt hạn thì bỏ qua để
    // quit không treo, vì plugin là code "ngoài" platform, không được phép giữ quit.
    nonisolated func shutdownAllBlocking(timeout: TimeInterval = 3) {
        let lifecycles = MainActor.assumeIsolated { self.lifecycles }
        guard !lifecycles.isEmpty else { return }
        let done = DispatchSemaphore(value: 0)
        Task.detached {
            await withTaskGroup(of: Void.self) { group in
                for plugin in lifecycles {
                    group.addTask { await plugin.shutdown() }
                }
            }
            done.signal()
        }
        _ = done.wait(timeout: .now() + timeout)
    }
}
