import AppKit
import KTPlatformContracts
import KTPluginKit
import ServiceManagement
import SwiftUI

struct ServicesScreen: View {
    @ObservedObject var vm: ServicesViewModel
    let nginxInclude: any NginxIncludeEditing
    let route: @MainActor (ServicesRoute) -> Void

    @EnvironmentObject private var feedback: KTFeedbackCenter

    @State private var editingNginxConf: NginxConfEditToken?

    private struct NginxConfEditToken: Identifiable { let id = UUID() }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header.padding(.horizontal, KTSpacing.screenGutter).padding(.top, 18)
            Text("Background services powering your local environment.")
                .font(.jbMono(13.5)).foregroundStyle(Color(hex: 0x8E8E93))
                .padding(.horizontal, KTSpacing.screenGutter).padding(.top, 6)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    let banners = banners
                    if !banners.isEmpty {
                        VStack(spacing: 8) {
                            ForEach(banners) { banner in
                                ServiceBannerView(
                                    severity: banner.severity,
                                    title: banner.title,
                                    message: banner.message,
                                    ctaTitle: banner.ctaTitle,
                                    action: banner.action
                                )
                            }
                        }
                        .padding(.bottom, 8)
                    }
                    ForEach(ServicesViewModel.groups, id: \.title) { group in
                        standardGroup(group)
                        // DB/cache engines: run + swap-installed here; install/uninstall on Runtimes.
                        if group.title == "Runtimes" { dbGroup }
                    }
                }
                .padding(.horizontal, KTSpacing.screenGutter)
                .padding(.top, 16)
                .padding(.bottom, 24)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(KTColor.contentBg)
        .sheet(item: $editingNginxConf) { _ in
            NginxIncludeEditorSheet(model: NginxIncludeEditorModel(nginxInclude: nginxInclude))
        }
        .task { await vm.refreshCATrust() }
        // Quay lại sau khi approve helper trong System Settings: re-check để banner approve tự clear.
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            vm.refreshDNS()
        }
        .ktFeedbackHost(feedback)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text("Services").font(KTType.screenTitle).tracking(KTType.screenTitleTracking).foregroundStyle(KTColor.ink)
            Spacer()
            KTButton(title: "Restart All", systemImage: "arrow.clockwise", kind: .secondary) {
                vm.restartAll(); feedback.toast("Restarting all services")
            }
            KTButton(title: "Start All", kind: .primary) {
                vm.startAll(); feedback.toast("Starting all services")
            }
        }
    }

    @ViewBuilder
    private func standardGroup(_ group: (title: String, ids: [ServiceID])) -> some View {
        let rows = vm.rows(for: group.ids)
        if !rows.isEmpty {
            Text(group.title.uppercased())
                .font(KTType.sectionLabel).tracking(KTType.sectionLabelTracking)
                .foregroundStyle(KTColor.muted)
                .padding(.horizontal, 2).padding(.top, 18).padding(.bottom, 8)
            KTListContainer { groupRows(rows) }
        }
    }

    @ViewBuilder
    private var dbGroup: some View {
        let entries = vm.dbEntries
        if !entries.isEmpty {
            Text("DATABASES & CACHE")
                .font(KTType.sectionLabel).tracking(KTType.sectionLabelTracking)
                .foregroundStyle(KTColor.muted)
                .padding(.horizontal, 2).padding(.top, 18).padding(.bottom, 8)
            KTListContainer {
                VStack(spacing: 0) {
                    ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                        let id = entry.state.id
                        DatabaseServiceRow(
                            state: entry.state,
                            installedVersions: entry.installed,
                            activeVersion: entry.active,
                            vm: vm,
                            onToggle: { vm.toggle(id) },
                            onRestart: { vm.restart(id) },
                            onOpenLogs: { route(.logs(sourceID: ServicesViewModel.logSourceID(id))) },
                            onSetActive: { handleSetActive(id: id, version: $0) },
                            onManageInRuntimes: { route(.runtimes) }
                        )
                        .equatable()
                        if index < entries.count - 1 {
                            Rectangle().fill(KTColor.sepFaint).frame(height: 0.5).padding(.leading, 18)
                        }
                    }
                }
            }
        }
    }

    private func handleSetActive(id: ServiceID, version: String) {
        if case let .failure(error) = vm.setActive(id, version: version) {
            feedback.toast(error.localizedDescription)
        }
    }

    private func groupRows(_ rows: [ServiceState]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, state in
                ServiceRow(
                    state: state,
                    canToggle: true,
                    vm: vm,
                    onToggle: { vm.toggle(state.id) },
                    onRestart: { vm.restart(state.id) },
                    onOpenLogs: { route(.logs(sourceID: ServicesViewModel.logSourceID(state.id))) },
                    onInstall: { vm.install(state.id) },
                    onCancelInstall: { vm.cancelInstall(state.id) },
                    onResetData: { vm.resetData(state.id) },
                    onEditConfig: state.id == .nginx ? { editingNginxConf = NginxConfEditToken() } : nil
                )
                .equatable()
                if index < rows.count - 1 {
                    Rectangle().fill(KTColor.sepFaint).frame(height: 0.5).padding(.leading, 18)
                }
            }
        }
    }

    private var banners: [ServiceBanner] {
        vm.banners(actions: ServiceBannerActions(
            onEnableDNS: { vm.enableDNS() },
            onResetDNS: { vm.resetDNS() },
            onOpenTLSSettings: { route(.settings) },
            onOpenLoginItems: { SMAppService.openSystemSettingsLoginItems() },
            onRestart: { vm.restart($0) }
        ))
    }
}
