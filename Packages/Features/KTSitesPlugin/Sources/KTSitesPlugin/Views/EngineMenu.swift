import KTPlatformContracts
import KTPluginKit
import SwiftUI

// Per-site web-engine picker (PHP only). Shows the running engine + backend port, lets the user
// switch Nginx↔Apache or install Apache on demand. Switching applies live: the new engine comes
// up on a fresh port and the front repoints to it, no Web Server restart.
struct EngineMenu: View {
    let current: SiteServerEngine
    let port: Int?
    let apacheInstalled: Bool
    let apacheInstalling: Bool
    let onSelect: (SiteServerEngine) -> Void
    let onInstallApache: () -> Void

    var body: some View {
        KTDropdown(width: 210, options: options) {
            KTDropdownChevronLabel(text: label)
        }
        .fixedSize()
        .ktTip("Web engine for this site. Switching applies live, no Web Server restart.")
    }

    private var label: String {
        let name = current == .apache ? "Apache" : "Nginx"
        guard let port else { return name }
        return "\(name) · :\(port)"
    }

    private var options: [KTDropdownOption] {
        var opts = [KTDropdownOption(label: "Nginx", active: current == .nginx) { onSelect(.nginx) }]
        if apacheInstalled {
            opts.append(KTDropdownOption(label: "Apache", active: current == .apache) { onSelect(.apache) })
        } else if apacheInstalling {
            opts.append(KTDropdownOption(label: "Installing Apache…", active: false) {})
        } else {
            opts.append(KTDropdownOption(label: "Install Apache…", active: false) { onInstallApache() })
        }
        return opts
    }
}
