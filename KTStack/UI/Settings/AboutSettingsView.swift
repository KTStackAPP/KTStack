import SwiftUI
import KTStackKit

struct AboutSettingsView: View {
    private var version: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
        return build.isEmpty ? short : "\(short) (\(build))"
    }

    var body: some View {
        Form {
            Section {
                HStack(spacing: KDSpacing.space3) {
                    Image(systemName: "bolt.horizontal.circle.fill")
                        .font(.system(size: 40)).foregroundStyle(Color.accentColor)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("KTStack").font(KDFont.title)
                        Text("Local web development host manager for macOS")
                            .font(KDFont.footnote).foregroundStyle(.secondary)
                        Text("Version \(version)").font(KDFont.footnote).foregroundStyle(.tertiary)
                    }
                }
                .padding(.vertical, KDSpacing.space1)
            }

            Section("Author") {
                LabeledContent("Tác giả", value: "Minh Trang")
                HStack {
                    Text("Website")
                    Spacer()
                    Link("nguyenkhoi.dev", destination: URL(string: "https://nguyenkhoi.dev")!)
                        .font(KDFont.body)
                }
            }

            Section {
                Text("© 2026 Minh Trang · nguyenkhoi.dev")
                    .font(KDFont.footnote).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding(KDSpacing.space4)
    }
}
