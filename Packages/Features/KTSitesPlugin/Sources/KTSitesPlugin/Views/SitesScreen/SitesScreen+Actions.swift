import KTPlatformContracts
import KTPluginKit
import SwiftUI

extension SitesScreen {
    func recheckType(_ site: SiteSummary) {
        guard let kind = vm.recheckKind(site.id) else { return }
        if kind == site.kind {
            feedback.toast("\(site.domain) is still a \(SiteVisuals.label(for: kind)) site")
        } else {
            feedback.toast("\(site.domain) is now a \(SiteVisuals.label(for: kind)) site")
        }
    }

    func toggleShare(_ site: SiteSummary, _ on: Bool) {
        if on {
            vm.startShare(site)
        } else {
            vm.stopShare(siteID: site.id)
        }
    }
}
