import Foundation
import KTStackCore

struct DoctorCommand {
    let client: KTIPCClient

    func run() {
        print("KTStack Diagnostics Probe")
        print(String(repeating: "=", count: 40))

        let paths = AppSupportPaths()
        check("KTStack Application Support", exists: FileManager.default.fileExists(atPath: paths.root.path))
        check("Unix IPC Socket (\(paths.ipcSocket.lastPathComponent))", exists: FileManager.default.fileExists(atPath: paths.ipcSocket.path))

        do {
            let ping = try client.call(method: "ping")
            print("  ✓ App IPC Connection: Online (\(ping))")
        } catch {
            print("  ✗ App IPC Connection: Offline (\(error.localizedDescription))")
        }

        check("Configuration Directory", exists: FileManager.default.fileExists(atPath: paths.config.path))
        check("Runtimes Directory", exists: FileManager.default.fileExists(atPath: paths.runtimes.path))
        check("Tools Directory", exists: FileManager.default.fileExists(atPath: paths.tools.path))
    }

    private func check(_ label: String, exists: Bool) {
        if exists {
            print("  ✓ \(label): Found")
        } else {
            print("  ✗ \(label): Missing")
        }
    }
}
