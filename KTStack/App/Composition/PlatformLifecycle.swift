import KTStackKit

// Teardown hệ thống lúc quit, chạy sau khi mọi plugin đã shutdown.
struct PlatformLifecycle {
    let server: LocalServerController

    func shutdownBlocking() {
        MainActor.assumeIsolated { server.shutdownForQuit() }
    }
}
