import KTPluginKit
import SwiftUI

/// Modal kết nối của tab Database. Chọn Database ở sidebar là modal bật, đóng lại thấy trang brand.
/// Mọi màn (danh sách, thêm, sửa, nhập) đổi tại chỗ trong một cửa sổ con, không lồng sheet.
@MainActor
struct ConnectionsModal: View {
    enum Mode {
        case list
        case create
        case edit(ConnectionProfile)
        case importURL
        case importSite
    }

    @EnvironmentObject private var store: ConnectionStore
    @EnvironmentObject private var documentVM: DocumentViewModel

    let plugin: KTDatabasePlugin
    @ObservedObject private var reachability: ServerReachabilityService

    @State private var mode: Mode
    @State private var selection: UUID?
    @State private var search = ""

    init(plugin: KTDatabasePlugin, mode: Mode = .list) {
        self.plugin = plugin
        _reachability = ObservedObject(wrappedValue: plugin.reachability)
        _mode = State(initialValue: mode)
    }

    var body: some View {
        content.ktFeedbackHost(plugin.modalFeedback)
    }

    @ViewBuilder
    private var content: some View {
        switch mode {
        case .list:
            listCard
        case .create:
            card { AddConnectionSheet(editing: nil, onClose: backToList) }
        case let .edit(profile):
            card { AddConnectionSheet(editing: profile, onClose: backToList) }
        case .importURL:
            card { ImportURLSheet(onClose: backToList) }
        case .importSite:
            card { ImportSiteSheet(sites: plugin.importableSites, onClose: backToList) }
        }
    }

    private var listCard: some View {
        KTModalCard(
            icon: "cylinder.split.1x2",
            tint: KTIconTint.db,
            title: "Connections",
            subtitle: "Open a saved connection or add a new one",
            width: 620,
            onClose: plugin.dismissConnections
        ) {
            ConnectionListPane(
                profiles: store.profiles,
                statusFor: { reachability.currentStatus(for: $0) },
                selection: $selection,
                search: $search,
                onCreate: { mode = .create },
                onImportURL: { mode = .importURL },
                onImportSite: { mode = .importSite },
                onOpen: open,
                onEdit: { mode = .edit($0) },
                onDuplicate: duplicate,
                onDelete: confirmDelete
            )
        }
    }

    /// Các form dùng lại chrome của sheet cũ nên chỉ cần scrim + nền card, không cần header modal.
    private func card(@ViewBuilder _ form: () -> some View) -> some View {
        ZStack {
            KTColor.modalScrim
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture(perform: backToList)
            form()
                .background(
                    RoundedRectangle(cornerRadius: KTRadius.modal, style: .continuous).fill(.white)
                )
        }
    }

    private func backToList() {
        mode = .list
    }

    private func open(_ profile: ConnectionProfile) {
        selection = profile.id
        guard profile.kind == .mongodb else {
            plugin.dismissConnections()
            plugin.openWorkspace(profile)
            return
        }
        Task {
            await documentVM.select(profile: profile)
            guard documentVM.connection == .connected else {
                if case let .failed(error) = documentVM.connection {
                    plugin.modalFeedback.toast(error.message)
                }
                return
            }
            plugin.dismissConnections()
            plugin.openDocumentBrowser(profile)
        }
    }

    // Bản sao mang id mới nên Keychain chưa có mật khẩu; người dùng nhập lại khi sửa.
    private func duplicate(_ profile: ConnectionProfile) {
        store.add(
            ConnectionProfile(
                name: "\(profile.name) copy", kind: profile.kind, host: profile.host,
                port: profile.port, user: profile.user, database: profile.database,
                filePath: profile.filePath, tlsMode: profile.tlsMode, readOnly: profile.readOnly
            )
        )
    }

    private func confirmDelete(_ profile: ConnectionProfile) {
        plugin.modalFeedback.confirm(
            title: "Delete connection?",
            message: "\(profile.name) is removed from KTStack. The database itself is not touched.",
            okLabel: "Delete"
        ) {
            if selection == profile.id { selection = nil }
            store.remove(profile)
        }
    }
}
