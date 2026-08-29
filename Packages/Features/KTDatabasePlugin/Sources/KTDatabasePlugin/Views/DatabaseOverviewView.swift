import KTPlatformContracts
import KTPluginKit
import SwiftUI

/// Dashboard tab Database (thu gọn): trạng thái engine managed + mở panel. Danh sách kết nối,
/// backup/restore đã dời sang cửa sổ "KTStack Database".
@MainActor
struct DatabaseOverviewView: View {
    @EnvironmentObject private var documentVM: DocumentViewModel

    let plugin: KTDatabasePlugin
    @ObservedObject private var reachability: ServerReachabilityService

    init(plugin: KTDatabasePlugin) {
        self.plugin = plugin
        _reachability = ObservedObject(wrappedValue: plugin.reachability)
    }

    private var engines: any DatabaseEngineManaging { plugin.engines }
    private var feedback: KTFeedbackCenter { plugin.feedback }
    private var sectionState: DatabaseSectionState { plugin.sectionState }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header.padding(.horizontal, KTSpacing.screenGutter).padding(.top, 18)
            engineList.padding(.horizontal, KTSpacing.screenGutter).padding(.top, 18).padding(.bottom, 24)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(KTColor.contentBg)
    }

    private var header: some View {
        HStack(spacing: 12) {
            Text("Database").font(KTType.screenTitle).tracking(KTType.screenTitleTracking).foregroundStyle(KTColor.ink)
            KTPill(text: "\(ConnectionProfile.managedProfiles.count) engines")
            Spacer()
            KTButton(title: "New Connection…", systemImage: "link", kind: .secondary) {
                sectionState.connectPresented = true
            }
            KTButton(title: "Open Database Panel", systemImage: "macwindow", kind: .primary) {
                plugin.openDatabasePanel()
            }
        }
    }

    private var engineList: some View {
        VStack(spacing: 10) {
            ForEach(ConnectionProfile.managedProfiles) { profile in
                engineRow(profile)
            }
        }
    }

    private func engineRow(_ profile: ConnectionProfile) -> some View {
        let engine = profile.kind.engine
        let installed = engine.map { plugin.engineInstalled($0) } ?? false
        let status = reachability.currentStatus(for: profile.id)
        let tint = KTEngineTint.of(profile.kind.rawValue)
        return HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 11)
                .fill(tint.bg)
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: "cylinder.split.1x2")
                        .font(.system(size: 16))
                        .foregroundStyle(tint.fg)
                )
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(engineLabel(profile.kind)).font(KTType.rowName).foregroundStyle(KTColor.ink)
                    Text("bundled").font(KTType.sub).foregroundStyle(KTColor.muted)
                }
                statusLine(status: status, installed: installed, host: "\(profile.host):\(profile.port)")
            }
            Spacer(minLength: 8)
            if !installed {
                KTButton(title: "Install", systemImage: "arrow.down.circle", kind: .secondary) {
                    if let engine { engines.install(engine) }
                }
            } else if status != .online {
                KTButton(title: "Start", systemImage: "play.fill", kind: .secondary) {
                    if let engine { engines.toggle(engine) }
                }
            }
            KTButton(title: "Open", kind: .primary) { open(profile) }
                .disabled(!installed)
        }
        .padding(.vertical, 13)
        .padding(.horizontal, 16)
        .background(RoundedRectangle(cornerRadius: 11, style: .continuous).fill(.white))
        .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).strokeBorder(KTColor.sep, lineWidth: 1))
    }

    private func statusLine(status: ServerStatus, installed: Bool, host: String) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color(for: status)).frame(width: 7, height: 7)
            Text(statusText(status: status, installed: installed, host: host))
                .font(KTType.sub).foregroundStyle(color(for: status))
        }
    }

    private func color(for status: ServerStatus) -> Color {
        switch status {
        case .online: KTColor.online
        case .connecting: KTColor.accent
        case .offline: KTColor.muted
        }
    }

    private func statusText(status: ServerStatus, installed: Bool, host: String) -> String {
        switch status {
        case .online: "Running · \(host)"
        case .connecting: "Checking…"
        case .offline: installed ? "Stopped" : "Not installed"
        }
    }

    private func open(_ profile: ConnectionProfile) {
        if profile.kind == .mongodb {
            Task {
                await documentVM.select(profile: profile)
                guard documentVM.connection == .connected else {
                    if case let .failed(error) = documentVM.connection { feedback.toast(error.message) }
                    return
                }
                plugin.openDocumentBrowser(profile)
            }
        } else {
            plugin.openWorkspace(profile)
        }
    }

    private func engineLabel(_ kind: DatabaseKind) -> String {
        switch kind {
        case .mysql: "MySQL"
        case .postgres: "PostgreSQL"
        case .sqlite: "SQLite"
        case .mongodb: "MongoDB"
        }
    }
}
