import SwiftUI
import AppKit
import KTStackKit

enum KTSiteVisuals {
    static func kind(for type: SiteType) -> KTSiteIconKind {
        switch type {
        case .php: return .code
        case .node: return .cube
        case .staticSite: return .db
        }
    }

    static func tint(for type: SiteType) -> KTTint {
        switch type {
        case .php: return KTIconTint.code
        case .node: return KTIconTint.cube
        case .staticSite: return KTIconTint.db
        }
    }
}

enum KTSiteActions {
    static func revealInFinder(_ site: Site) {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: site.path)])
    }

    static func openTerminal(_ site: Site) {
        let folder = URL(fileURLWithPath: site.path)
        let terminal = URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app")
        NSWorkspace.shared.open([folder], withApplicationAt: terminal,
                                configuration: NSWorkspace.OpenConfiguration())
    }

    static func openInBrowser(_ site: Site) {
        let scheme = site.secure ? "https" : "http"
        guard let url = URL(string: "\(scheme)://\(site.domain)/") else { return }
        NSWorkspace.shared.open(url)
    }

    @discardableResult
    static func configureVSCode(_ site: Site) throws -> URL {
        let written = try IDEDebugConfigWriter().writeVSCode(
            projectRoot: URL(fileURLWithPath: site.path),
            docroot: URL(fileURLWithPath: site.docroot))
        NSWorkspace.shared.activateFileViewerSelecting([written])
        return written
    }
}
