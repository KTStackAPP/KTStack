import SwiftUI
import KTStackKit

struct DashboardSidebarView: View {
    @Binding var selection: SidebarItem?
    let siteCount: Int
    let serverStatus: ServiceStatus

    var body: some View {
        VStack(spacing: 0) {
            identityRow
                .padding(.horizontal, KDSpacing.space4)
                .padding(.top, KDSpacing.space4)
                .padding(.bottom, KDSpacing.space2)

            List(selection: $selection) {
                ForEach(SidebarSection.allCases) { section in
                    Section(section.title) {
                        ForEach(section.items) { item in
                            sidebarRow(for: item).tag(item)
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)

            serverCard
                .padding(KDSpacing.space4)
        }
        .background(.regularMaterial)
    }

    private var identityRow: some View {
        HStack(spacing: KDSpacing.space2) {
            Image(systemName: "bolt.horizontal.circle.fill")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 36, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.accentColor.opacity(0.12)))

            Text("KTStack")
                .font(KDFont.headline)

            Spacer(minLength: KDSpacing.space2)

            Text("Pro")
                .font(KDFont.footnote.weight(.medium))
                .foregroundStyle(Color.accentColor)
                .padding(.vertical, KDSpacing.space1)
                .padding(.horizontal, KDSpacing.space2)
                .background(Capsule().fill(Color.accentColor.opacity(0.12)))
        }
    }

    private func sidebarRow(for item: SidebarItem) -> some View {
        HStack(spacing: KDSpacing.space2) {
            Label(item.title, systemImage: item.symbol)
            Spacer(minLength: KDSpacing.space2)
            if item == .sites {
                Text("\(siteCount)")
                    .font(KDFont.footnote.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 2)
                    .padding(.horizontal, KDSpacing.space2)
                    .background(Capsule().fill(Color(nsColor: .controlColor)))
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var serverCard: some View {
        VStack(alignment: .leading, spacing: KDSpacing.space2) {
            HStack(spacing: KDSpacing.space2) {
                Circle()
                    .fill(serverStatus.color)
                    .frame(width: 7, height: 7)
                Text("Server \(serverStatus.label)")
                    .font(KDFont.footnote.weight(.medium))
            }
            Text("Version \(versionText)")
                .font(KDFont.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(KDSpacing.space3)
        .background(
            RoundedRectangle(cornerRadius: KDRadius.card)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.72)))
        .overlay(
            RoundedRectangle(cornerRadius: KDRadius.card)
                .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 0.5))
        .accessibilityLabel("Server \(serverStatus.label), version \(versionText)")
    }

    private var versionText: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0"
    }
}
