import SwiftUI

/// Shell hỏi capability bằng cast, không switch theo id; @MainActor chỉ đặt trên requirement UI.
public protocol MenuBarProviding {
    @MainActor
    func makeMenuBarView() -> AnyView
}

public protocol SettingsProviding {
    @MainActor
    func makeSettingsPane() -> AnyView
}

public protocol DoctorCheckProviding {
    /// Probe fs/process/socket, không khóa main.
    func doctorChecks() async -> [DoctorCheck]
}

public protocol PluginLifecycle {
    func start() async
    /// Chỉ dọn resource riêng của plugin: cancel task, stop watcher, flush state.
    /// Chạy trong quit khi coordinator block main thread, nên KHÔNG được hop @MainActor: deadlock.
    func shutdown() async
}

/// Shell keep-alive ẩn/hiện view bằng isHidden nên onAppear SwiftUI không refire; plugin cần tín
/// hiệu tab active/inactive (đổi tab, mở/đóng window) để bật/tắt polling.
public protocol SectionActivationObserving {
    @MainActor
    func sectionDidActivate()
    @MainActor
    func sectionDidDeactivate()
}
