import KTPluginKit
import SwiftUI

struct PhpMenu: View {
    let current: String
    let versions: [String]
    let label: (String) -> String
    let onSelect: (String) -> Void

    var body: some View {
        KTDropdown(
            width: 150,
            options: versions.map { version in
                KTDropdownOption(label: "PHP \(label(version))", active: version == current) { onSelect(version) }
            }
        ) {
            KTDropdownChevronLabel(text: "PHP \(label(current))")
        }
        .fixedSize()
        .ktTip("Switch the PHP version for this site")
    }
}
