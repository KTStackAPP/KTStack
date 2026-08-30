import KTPluginKit
import SwiftUI

/// Menu "Add from Existing", dùng chung cho panel trái (có chữ) và toolbar phải (chỉ icon).
struct AddFromExistingMenu: View {
    enum Style { case titled, icon }

    let style: Style
    let onImportURL: () -> Void
    let onImportSite: () -> Void

    var body: some View {
        Menu {
            Button("From URL…", action: onImportURL)
            Button("From Site…", action: onImportSite)
        } label: {
            switch style {
            case .titled:
                Label("Add from Existing", systemImage: "square.and.arrow.down")
                    .font(KTType.control)
            case .icon:
                Image(systemName: "square.and.arrow.down")
            }
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .accessibilityLabel("Add from Existing")
    }
}
