import KTStackKit
import SwiftUI

// Per-site web-engine picker (PHP only). Shows the running engine + backend port, lets the user
// switch Nginx↔Apache or install Apache on demand. The change is persisted immediately but the
// menu reminds that the Web Server must be restarted to pick it up.
struct KTEngineMenu: View {
    let current: WebServerEngine
    let port: Int?
    let apacheInstalled: Bool
    let apacheInstalling: Bool
    let onSelect: (WebServerEngine) -> Void
    let onInstallApache: () -> Void

    var body: some View {
        KTDropdown(width: 210, options: options) {
            KTDropdownChevronLabel(text: label)
        }
        .fixedSize()
        .ktTip("Web engine for this site. Restart the Web Server after changing it to apply.")
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
        opts.append(KTDropdownOption(label: "↻ Restart Web Server to apply", active: false) {})
        return opts
    }
}
