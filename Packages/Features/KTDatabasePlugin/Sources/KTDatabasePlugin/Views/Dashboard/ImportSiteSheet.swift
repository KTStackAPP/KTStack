import KTPlatformContracts
import KTPluginKit
import SwiftUI

/// Chọn một site KTStack, đọc DB_* trong .env của nó rồi mở AddConnectionSheet đã điền sẵn.
struct ImportSiteSheet: View {
    @Environment(\.dismiss) private var dismiss

    let sites: [SiteSummary]
    var onClose: (() -> Void)?

    @State private var selection: UUID?
    @State private var error: String?
    @State private var draft: ConnectionDraft?

    var body: some View {
        if let draft {
            AddConnectionSheet(editing: nil, draft: draft, onClose: onClose)
        } else {
            picker
        }
    }

    private var picker: some View {
        VStack(alignment: .leading, spacing: KDSpacing.space3) {
            Text("Add from Site").font(KDFont.headline)
            if sites.isEmpty {
                Text("No site with a project folder is set up yet.")
                    .font(KDFont.subheadline).foregroundStyle(.secondary)
            } else {
                List(sites, selection: $selection) { site in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(site.name).font(KDFont.body)
                        Text(site.domain).font(KDFont.footnote).foregroundStyle(.secondary)
                    }
                    .tag(site.id)
                }
                .frame(height: 220)
            }
            if let error {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(KDFont.footnote).foregroundStyle(.orange)
            }
            Divider()
            HStack {
                Spacer()
                Button("Cancel") { if let onClose { onClose() } else { dismiss() } }
                    .keyboardShortcut(.cancelAction)
                Button("Continue", action: read)
                    .keyboardShortcut(.defaultAction)
                    .disabled(selection == nil)
            }
        }
        .padding(KDSpacing.space4)
        .frame(width: 440)
    }

    private func read() {
        guard let site = sites.first(where: { $0.id == selection }) else { return }
        do {
            draft = try SiteEnvReader.read(at: site.path)
        } catch {
            self.error = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}
