import AppKit
import KTStackCore
import KTStackKit

extension AppDelegate {
    @MainActor
    func makeUninstaller() -> UninstallService {
        let uninstaller = UninstallService(
            paths: AppSupportPaths(),
            dns: dns,
            mkcertBinary: Self.bundleBinDir.appendingPathComponent("mkcert"),
            quiesce: { [weak self] in
                self?.services.stopPolling()
                self?.ipcListener.stop()
            }
        )
        uninstaller.onFinished = { state in
            guard state == .done else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { NSApp.terminate(nil) }
        }
        return uninstaller
    }
}
