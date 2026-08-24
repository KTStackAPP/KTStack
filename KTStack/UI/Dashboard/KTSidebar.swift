import AppKit
import KTPluginKit
import KTStackKit
import SwiftUI

struct SidebarRowModel: Identifiable {
    let id: String
    let title: String
    let symbol: String

    init(id: String, title: String, symbol: String) {
        self.id = id
        self.title = title
        self.symbol = symbol
    }

    init(from item: SidebarItem) {
        self.init(id: item.rawValue, title: item.title, symbol: item.symbol)
    }
}

struct KTSidebarGroup: Identifiable {
    let title: String
    let rows: [SidebarRowModel]
    var id: String { title }
}

struct KTSidebar: View {
    let sections: [KTSidebarGroup]
    @Binding var selection: String
    let siteCount: Int
    let serverStatus: ServiceStatus
    let version: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Color.clear.frame(height: KTMetric.trafficLightInset)
            identity
            ForEach(Array(sections.enumerated()), id: \.element.id) { index, section in
                group(section, topPadding: index == 0 ? 0 : 18)
            }
            Spacer(minLength: 12)
            KTSidebarFooterCard(status: serverStatus, version: version)
                .padding(.bottom, 14)
        }
        .padding(.horizontal, 14)
        .frame(width: KTMetric.sidebarWidth)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(KTColor.sidebarBackground.ignoresSafeArea())
        .overlay(alignment: .trailing) {
            Rectangle().fill(KTColor.hairline).frame(width: KTMetric.hairline)
        }
    }

    private var identity: some View {
        HStack(spacing: 10) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .frame(width: 32, height: 32)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .shadow(color: Color(hex: 0x140F28, opacity: 0.4), radius: 4, y: 3)
            Text("KTStack")
                .font(.jbMono(16, .bold))
                .foregroundStyle(KTColor.ink)
            Spacer(minLength: 0)
        }
        .padding(.leading, 6)
        .padding(.top, 4)
        .padding(.bottom, 18)
    }

    private func group(_ section: KTSidebarGroup, topPadding: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(section.title)
                .font(KTType.sectionLabel)
                .tracking(KTType.sectionLabelTracking)
                .foregroundStyle(KTColor.muted)
                .padding(.horizontal, 8)
                .padding(.top, topPadding)
                .padding(.bottom, 8)
            ForEach(section.rows) { row in
                KTSidebarRow(
                    row: row,
                    isActive: selection == row.id,
                    badge: row.id == "sites" ? siteCount : nil,
                    action: { selection = row.id }
                )
            }
        }
    }
}
