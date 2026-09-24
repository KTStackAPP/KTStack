import AppKit
import KTPluginKit
import KTStackKit

extension AppDelegate {
    func applicationShouldTerminate(_: NSApplication) -> NSApplication.TerminateReply {
        MainActor.assumeIsolated {
            let reasons = plugins.compactMap { ($0 as? TerminationVetoing)?.pendingWorkDescription() }
            if !reasons.isEmpty, !Self.confirmQuit(reasons) { return .terminateCancel }
            AppTermination.begin()
            return .terminateNow
        }
    }

    @MainActor
    private static func confirmQuit(_ reasons: [String]) -> Bool {
        let alert = NSAlert()
        alert.messageText = "Quit KTStack?"
        alert.informativeText = reasons.joined(separator: "\n")
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Cancel")
        alert.addButton(withTitle: "Discard & Quit")
        NSApp.activate(ignoringOtherApps: true)
        return alert.runModal() == .alertSecondButtonReturn
    }
}
