import Foundation

public extension DatabaseV2ViewModel {
    /// Tab idle quá lâu: đóng driver nhưng giữ mọi @Published (rows, staged, scroll). connectionState
    /// vẫn .connected để UI tiếp tục hiện dữ liệu; driver == nil nên mọi entry cần nối phải qua ensureConnected().
    func suspendConnection() async {
        guard case .connected = connectionState, !isSuspended, let old = driver else { return }
        driver = nil
        isSuspended = true
        await old.closeSession()
    }

    /// Nối lại profile đã lưu mà không xoá dữ liệu đang hiện; rebind staged editor sang driver mới để commit
    /// dùng connection sống. Không bump generation nên token in-flight (nếu có) vẫn hợp lệ.
    func resumeConnection() async {
        guard isSuspended, let profile = activeProfile else { return }
        guard let newDriver = makeDriver(profile, passwordFor(profile)) else {
            isSuspended = false
            connectionState = .failed("Unsupported engine: \(profile.kind.rawValue)")
            return
        }
        do {
            try await newDriver.ping()
            try? await newDriver.openSession()
            driver = newDriver
            capabilities = newDriver.capabilities
            isSuspended = false
            connectionState = .connected
            if let database = selectedDatabase {
                staged?.rebind(driver: newDriver, database: database)
            }
        } catch {
            connectionState = .failed("Couldn't reconnect to \(profile.name): \(error.localizedDescription)")
        }
    }

    /// Gọi đầu mọi thao tác cần driver; resume tab đã suspend trước khi chạm connection.
    func ensureConnected() async {
        if isSuspended { await resumeConnection() }
    }

    func connectedDriver() async -> RelationalDriver? {
        await ensureConnected()
        return driver
    }
}
