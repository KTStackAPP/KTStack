import AppKit
import KTStackKit

enum AppRelaunch {
    static func configuration() -> NSWorkspace.OpenConfiguration {
        let config = NSWorkspace.OpenConfiguration()
        config.createsNewApplicationInstance = true
        config.arguments = RelaunchGate.arguments(waitingFor: ProcessInfo.processInfo.processIdentifier)
        return config
    }
}
