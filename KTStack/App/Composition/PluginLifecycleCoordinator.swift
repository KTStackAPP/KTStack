import Foundation
import KTPluginKit

// Gọi lifecycle của plugin. Thứ tự giữa các plugin độc lập (mỗi plugin chỉ đụng resource riêng).
@MainActor
final class PluginLifecycleCoordinator {
    private let plugins: [any KTStackPlugin]

    init(plugins: [any KTStackPlugin]) {
        self.plugins = plugins
    }

    func startAll() {
        for case let plugin as any PluginLifecycle in plugins {
            Task.detached { await plugin.start() }
        }
    }

    // Block main tối đa `timeout` (plugin shutdown là file ops nhanh); vượt hạn thì bỏ qua để
    // quit không treo, vì plugin là code "ngoài" platform, không được phép giữ quit.
    nonisolated func shutdownAllBlocking(timeout: TimeInterval = 3) {
        let lifecycles = MainActor.assumeIsolated { plugins.compactMap { $0 as? any PluginLifecycle } }
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
