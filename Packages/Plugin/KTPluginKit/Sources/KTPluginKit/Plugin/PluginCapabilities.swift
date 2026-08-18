import SwiftUI

// Shell hỏi capability bằng cast, không switch theo id; @MainActor chỉ đặt trên requirement UI.
public protocol MenuBarProviding {
    @MainActor func makeMenuBarView() -> AnyView
}

public protocol SettingsProviding {
    @MainActor func makeSettingsPane() -> AnyView
}

public protocol DoctorCheckProviding {
    // Probe fs/process/socket, không khóa main.
    func doctorChecks() async -> [DoctorCheck]
}

public protocol PluginLifecycle {
    func start() async
    // Chỉ dọn resource riêng của plugin: cancel task, stop watcher, flush state.
    func shutdown() async
}
