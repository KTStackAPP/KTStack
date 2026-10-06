import KTPlatformContracts
import KTPluginKit
import SwiftUI

struct SiteInspector: View {
    enum Sheet: String, Identifiable {
        case environment, directives, workers
        var id: String {
            rawValue
        }
    }

    private static let columnMin: CGFloat = 320
    private static let gap: CGFloat = 18
    private static let padding = EdgeInsets(top: 22, leading: 28, bottom: 22, trailing: 28)

    @ObservedObject var vm: SitesViewModel
    @ObservedObject var pane: SitesPaneModel
    let actions: SiteInspectorActions

    @State var sheet: Sheet?

    var body: some View {
        Group {
            if let site = vm.sites.first(where: { $0.id == pane.selectedID }) {
                content(site)
            } else {
                Text("Select a site")
                    .font(KTType.body)
                    .foregroundStyle(KTColor.muted)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(KTColor.contentBg)
    }

    private func content(_ site: SiteSummary) -> some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                scroll(site, width: geo.size.width)
                footer(site)
            }
        }
        .id(site.id)
    }

    private func scroll(_ site: SiteSummary, width: CGFloat) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Self.gap) {
                SiteInspectorHeader(
                    site: site,
                    framework: framework(site),
                    endOfLife: site.kind == .php && vm.isEndOfLife(site.phpVersion),
                    canOpen: SiteInspectorInput.canOpen(
                        kind: site.kind,
                        serverRunning: vm.server.isRunning,
                        upstreamRunning: upstreamRunning(site)
                    ),
                    editors: vm.editors,
                    preferredEditor: vm.preferredEditor,
                    onOpenLogs: { actions.openLogs(site) },
                    onRecheckType: { actions.recheckType(site) },
                    onRemove: { actions.remove(site) }
                )
                SiteSettingsHost(site: site, vm: vm) { settings in
                    cards(site, settings: settings, twoColumns: fitsTwoColumns(width))
                        .sheet(item: $sheet) { sheetContent($0, site: site, settings: settings) }
                }
                // Model giữ kind lúc tạo, nên dựng lại khi Re-detect đổi loại site.
                .id(site.kind)
            }
            .padding(Self.padding)
        }
    }

    private func fitsTwoColumns(_ width: CGFloat) -> Bool {
        width >= Self.columnMin * 2 + Self.gap + Self.padding.leading + Self.padding.trailing
    }

    /// Đổi layout bằng AnyLayout để giữ nguyên view khi chuyển một/hai cột.
    private func cards(_ site: SiteSummary, settings: SiteSettingsModel, twoColumns: Bool) -> some View {
        let layout = twoColumns
            ? AnyLayout(HStackLayout(alignment: .top, spacing: Self.gap))
            : AnyLayout(VStackLayout(spacing: Self.gap))
        return layout {
            VStack(spacing: Self.gap) {
                domainCard(site, settings: settings)
                securityCard(site)
            }
            .frame(maxWidth: .infinity, alignment: .top)
            VStack(spacing: Self.gap) {
                runtimeCard(site)
                advancedCard(site, settings: settings)
            }
            .frame(maxWidth: .infinity, alignment: .top)
        }
    }

    private func footer(_ site: SiteSummary) -> some View {
        HStack(spacing: 8) {
            if site.kind == .php {
                KTButton(title: "Restore Backup…", kind: .secondary) { actions.restore(site) }
                KTButton(title: "Configure VS Code", kind: .secondary) { actions.configureVSCode(site) }
            }
            Spacer()
            KTButton(title: "Remove Site…", kind: .danger) { actions.remove(site) }
        }
        .padding(.horizontal, Self.padding.leading)
        .padding(.vertical, 12)
        .background(KTColor.contentBg)
        .overlay(alignment: .top) { Rectangle().fill(KTColor.sep).frame(height: 1) }
    }

    func framework(_ site: SiteSummary) -> PHPFramework {
        vm.frameworks[site.id] ?? .plain
    }

    func upstreamRunning(_ site: SiteSummary) -> Bool {
        vm.upstreamRunning[site.id] ?? false
    }
}
