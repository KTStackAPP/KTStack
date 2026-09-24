import KTPlatformContracts
import KTPluginKit
import SwiftUI

struct RemoveSiteSheet: View {
    let site: SiteSummary
    let onRemove: (SiteRemovalOptions) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var options = SiteRemovalOptions()

    var body: some View {
        VStack(alignment: .leading, spacing: KDSpacing.space3) {
            Text("Remove \(site.domain)?").font(KDFont.title)
            Text(SiteRemovalOptions.summary(site, options: options))
                .font(KDFont.footnote)
                .fixedSize(horizontal: false, vertical: true)
            if SiteRemovalOptions.canTrashFolder(site) {
                Toggle("Move folder to Trash", isOn: $options.moveFolderToTrash)
                    .toggleStyle(.checkbox)
                    .help(site.path)
            }
            if site.kind != .proxy, site.databaseName != nil {
                Toggle("Drop its MySQL database", isOn: $options.dropDatabase)
                    .toggleStyle(.checkbox)
            }
            HStack {
                Spacer()
                KTButton(title: "Cancel", kind: .secondary) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                KTButton(title: "Remove Site", kind: .danger) {
                    dismiss()
                    onRemove(options)
                }
            }
        }
        .padding(KDSpacing.space4)
        .frame(width: 460)
    }
}
