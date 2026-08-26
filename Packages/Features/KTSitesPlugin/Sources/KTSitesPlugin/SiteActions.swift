import AppKit
import Foundation
import KTPlatformContracts

enum SiteActions {
    static func revealInFinder(_ site: SiteSummary) {
        guard !site.path.isEmpty else { return }
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: site.path)])
    }

    static func openTerminal(_ site: SiteSummary) {
        guard !site.path.isEmpty else { return }
        let folder = URL(fileURLWithPath: site.path)
        let terminal = URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app")
        NSWorkspace.shared.open(
            [folder],
            withApplicationAt: terminal,
            configuration: NSWorkspace.OpenConfiguration()
        )
    }

    static func openInBrowser(_ site: SiteSummary) {
        let scheme = site.secure ? "https" : "http"
        guard let url = URL(string: "\(scheme)://\(site.domain)/") else { return }
        NSWorkspace.shared.open(url)
    }

    static func startNodeInTerminal(_ site: SiteSummary) {
        guard let port = site.nodePort else { return }
        let quotedDir = "'" + site.path.replacingOccurrences(of: "'", with: "'\\''") + "'"
        let base = "cd \(quotedDir) && export PORT=\(port)"
        let shell: String
        if let command = resolvedStartCommand(site) {
            shell = base + " && " + command
        } else {
            let hint = "KTStack: PORT=\(port) set for \(site.domain). Run your dev server, e.g. npm run dev"
            shell = base + " && clear && echo \"\(hint)\""
        }
        let escaped = shell
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        proc.arguments = [
            "-e", "tell application \"Terminal\" to do script \"\(escaped)\"",
            "-e", "tell application \"Terminal\" to activate",
        ]
        try? proc.run()
    }

    private static func resolvedStartCommand(_ site: SiteSummary) -> String? {
        if let stored = site.nodeCommand?.trimmingCharacters(in: .whitespacesAndNewlines), !stored.isEmpty {
            return stored
        }
        return NodeStartCommand.suggested(at: URL(fileURLWithPath: site.path))
    }

    @discardableResult
    static func configureVSCode(_ site: SiteSummary, ide: SiteIDEConfiguring) throws -> URL {
        let written = try ide.writeVSCodeDebugConfig(
            projectRoot: URL(fileURLWithPath: site.path),
            docroot: URL(fileURLWithPath: site.docroot)
        )
        NSWorkspace.shared.activateFileViewerSelecting([written])
        return written
    }
}
