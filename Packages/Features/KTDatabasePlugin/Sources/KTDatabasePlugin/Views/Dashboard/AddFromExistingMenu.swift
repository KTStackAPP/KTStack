import SwiftUI

/// Menu "Add from Existing" trên toolbar modal kết nối.
struct AddFromExistingMenu: View {
    let onImportURL: () -> Void
    let onImportSite: () -> Void

    var body: some View {
        Menu {
            Button("From URL…", action: onImportURL)
            Button("From Site…", action: onImportSite)
        } label: {
            Image(systemName: "square.and.arrow.down")
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .accessibilityLabel("Add from Existing")
    }
}
