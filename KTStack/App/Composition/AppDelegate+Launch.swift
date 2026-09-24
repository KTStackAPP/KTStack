import AppKit
import CoreServices
import KTStackKit

extension AppDelegate {
    static var bundleBinDir: URL {
        Bundle.main.resourceURL?.appendingPathComponent("bin", isDirectory: true)
            ?? Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/bin", isDirectory: true)
    }

    static func yieldToRunningInstance() -> Bool {
        if let pid = RelaunchGate.pidToWaitFor(in: ProcessInfo.processInfo.arguments) {
            RelaunchGate.waitForExit(of: pid, timeout: 15)
        }
        guard let existing = alreadyRunningInstance() else { return false }
        existing.activate(options: [.activateAllWindows])
        return true
    }

    private static func alreadyRunningInstance() -> NSRunningApplication? {
        guard let bundleID = Bundle.main.bundleIdentifier else { return nil }
        let current = NSRunningApplication.current
        return NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            .first { $0.processIdentifier != current.processIdentifier }
    }

    func applicationWillFinishLaunching(_: Notification) {
        let event = NSAppleEventManager.shared().currentAppleEvent
        LaunchContext.launchedAsLoginItem = event?.paramDescriptor(forKeyword: keyAELaunchedAsLogInItem) != nil
    }

    @MainActor
    func presentDashboardOnLaunch() {
        guard !LaunchContext.launchedAsLoginItem else { return }
        showDashboard()
    }

    func applicationShouldHandleReopen(_: NSApplication, hasVisibleWindows: Bool) -> Bool {
        guard !hasVisibleWindows else { return true }
        MainActor.assumeIsolated { showDashboard() }
        return false
    }

    @MainActor
    func showDashboard() {
        AppActivationPolicy.activateRegular()
        if AppActivationPolicy.focusDashboard() { return }
        DashboardOpener.shared.open()
        DispatchQueue.main.async {
            AppActivationPolicy.activateRegular()
            AppActivationPolicy.resizeDashboard(toFraction: 0.8)
        }
    }
}

enum LaunchContext {
    static var launchedAsLoginItem = false
}
