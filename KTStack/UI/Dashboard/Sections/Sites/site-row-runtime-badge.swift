import SwiftUI
import KTStackKit

struct SiteRowRuntimeBadge: View {
    let type: SiteType
    let phpVersion: String
    let availableVersions: [String]
    let onSetVersion: (String) -> Void

    var body: some View {
        if type == .php {
            Menu {
                ForEach(availableVersions, id: \.self) { version in
                    Button(version) { onSetVersion(version) }
                }
            } label: {
                HStack(spacing: KDSpacing.space1) {
                    Text("PHP \(phpVersion)")
                        .lineLimit(1)
                    Spacer(minLength: KDSpacing.space1)
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .font(KDFont.footnote)
                .padding(.vertical, KDSpacing.space1)
                .padding(.horizontal, KDSpacing.space2)
                .frame(width: 108, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: KDRadius.control)
                        .fill(Color(nsColor: .textBackgroundColor)))
                .overlay(
                    RoundedRectangle(cornerRadius: KDRadius.control)
                        .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 0.5))
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .accessibilityLabel("PHP version \(phpVersion)")
        } 
    }
}
