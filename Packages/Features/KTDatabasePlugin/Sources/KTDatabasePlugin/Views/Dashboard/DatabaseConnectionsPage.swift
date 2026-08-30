import KTPlatformContracts
import KTPluginKit
import SwiftUI

/// Tab Database: panel thương hiệu + hành động bên trái, danh sách kết nối bên phải.
@MainActor
struct DatabaseConnectionsPage: View {
    @EnvironmentObject private var store: ConnectionStore
    @EnvironmentObject private var documentVM: DocumentViewModel

    let plugin: KTDatabasePlugin
    @ObservedObject private var reachability: ServerReachabilityService

    @State private var selection: UUID?
    @State private var search = ""
    @State private var sheet: ConnectionSheet?

    init(plugin: KTDatabasePlugin) {
        self.plugin = plugin
        _reachability = ObservedObject(wrappedValue: plugin.reachability)
    }

    enum ConnectionSheet: Identifiable {
        case create
        case edit(ConnectionProfile)
        case importURL
        case importSite

        var id: String {
            switch self {
            case .create: "create"
            case let .edit(profile): "edit-\(profile.id)"
            case .importURL: "import-url"
            case .importSite: "import-site"
            }
        }
    }

    /// Dưới ngưỡng này panel trái bị ẩn, ba hành động của nó dồn vào toolbar danh sách.
    private static let brandPanelMinWidth: CGFloat = 640

    var body: some View {
        GeometryReader { proxy in
            let compact = proxy.size.width < Self.brandPanelMinWidth
            HStack(spacing: 0) {
                if !compact {
                    DatabaseBrandPanel(
                        onCreate: { sheet = .create },
                        onImportURL: { sheet = .importURL },
                        onImportSite: { sheet = .importSite },
                        onOpenPanel: { plugin.openDatabasePanel() }
                    )
                }
                listPane(compact: compact)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(KTColor.contentBg)
        .sheet(item: $sheet, content: sheetContent)
    }

    private func listPane(compact: Bool) -> some View {
        ConnectionListPane(
            profiles: store.allProfiles,
            statusFor: { reachability.currentStatus(for: $0) },
            engineInstalled: { plugin.engineInstalled($0) },
            compact: compact,
            selection: $selection,
            search: $search,
            onCreate: { sheet = .create },
            onImportURL: { sheet = .importURL },
            onImportSite: { sheet = .importSite },
            onOpenPanel: { plugin.openDatabasePanel() },
            onOpen: open,
            onInstallEngine: { plugin.engines.install($0) },
            onStartEngine: { plugin.engines.toggle($0) },
            onEdit: { sheet = .edit($0) },
            onDuplicate: duplicate,
            onDelete: confirmDelete
        )
    }

    @ViewBuilder
    private func sheetContent(_ sheet: ConnectionSheet) -> some View {
        switch sheet {
        case .create: AddConnectionSheet(editing: nil)
        case let .edit(profile): AddConnectionSheet(editing: profile)
        case .importURL: ImportURLSheet()
        case .importSite: ImportSiteSheet(sites: importableSites)
        }
    }

    private var importableSites: [SiteSummary] {
        plugin.sites.catalog.sites.filter { !$0.path.isEmpty }
    }

    private func open(_ profile: ConnectionProfile) {
        selection = profile.id
        guard profile.kind == .mongodb else {
            plugin.openWorkspace(profile)
            return
        }
        Task {
            await documentVM.select(profile: profile)
            guard documentVM.connection == .connected else {
                if case let .failed(error) = documentVM.connection { plugin.feedback.toast(error.message) }
                return
            }
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
        plugin.feedback.confirm(
            title: "Delete connection?",
            message: "\(profile.name) is removed from KTStack. The database itself is not touched.",
            okLabel: "Delete"
        ) {
            if selection == profile.id { selection = nil }
            store.remove(profile)
        }
    }
}
