import Combine
import Foundation
import os

private let workspaceSignposter = OSSignposter(subsystem: "com.ktstack.database", category: "workspace")

/// Gom trạng thái cửa sổ workspace: danh sách profile (đồng bộ ConnectionStore), chấm engine
/// (mirror ServerReachabilityService), cache schema theo (profile, database), profile/db đang chọn.
@MainActor
public final class WorkspaceStore: ObservableObject {
    @Published public private(set) var profiles: [ConnectionProfile] = []
    @Published public private(set) var engineStatuses: [UUID: ServerStatus] = [:]
    @Published public private(set) var schemaCache: [SchemaKey: SchemaSnapshot] = [:]
    @Published public var selectedProfileID: UUID?
    @Published public var activeDatabase: String?

    // Pool tab theo object: mỗi tab một VM + connection riêng (quyết định user 2026-08-29).
    @Published public private(set) var tabs: [WorkspaceTabSession] = []
    @Published public var activeTabID: UUID?

    // Ý định UI dùng chung giữa toolbar (NSToolbar host) và nội dung: sidebar/inspector, focus filter.
    // Split controller quan sát hai cờ này để collapse/expand pane; key đóng băng.
    @Published public var sidebarVisible: Bool {
        didSet { UserDefaults.standard.set(sidebarVisible, forKey: Self.sidebarKey) }
    }
    @Published public var inspectorVisible: Bool {
        didSet { UserDefaults.standard.set(inspectorVisible, forKey: Self.inspectorKey) }
    }
    @Published public var filterFocusToken = 0
    // Ý định từ toolbar window-level: mở sheet Backups / modal New Database (root nối v1 rồi mở).
    @Published public var backupsRequest = 0
    @Published public var newDatabaseRequest = 0
    // Từ menu pill: ngắt kết nối tab hiện tại / mở kết nối khác ở tab cửa sổ mới.
    @Published public var disconnectRequest = 0
    @Published public var openConnectionRequest = 0
    // Yêu cầu nối một profile vào cửa sổ đang mở (DatabaseWindows đẩy vào tab chưa nối).
    @Published public private(set) var activationToken = 0
    public private(set) var activationProfileID: UUID?
    private static let sidebarKey = "KTStack.databaseSidebarVisible"
    private static let inspectorKey = "KTStack.databaseInspectorVisible"

    public let recentStore: RecentObjectStore
    let makeViewModel: (@MainActor () -> DatabaseV2ViewModel)?
    let tabIdleInterval: TimeInterval

    private let reachability: ServerReachabilityService
    private let objectLoader: (SchemaKey) async throws -> [TableInfo]
    private var cancellables: Set<AnyCancellable> = []

    public init(
        connectionStore: ConnectionStore,
        reachability: ServerReachabilityService,
        recentStore: RecentObjectStore,
        objectLoader: @escaping (SchemaKey) async throws -> [TableInfo],
        makeViewModel: (@MainActor () -> DatabaseV2ViewModel)? = nil,
        tabIdleInterval: TimeInterval = 300
    ) {
        self.reachability = reachability
        self.recentStore = recentStore
        self.objectLoader = objectLoader
        self.makeViewModel = makeViewModel
        self.tabIdleInterval = tabIdleInterval
        // Sidebar mặc định hiện khi chưa có key; inspector mặc định ẩn.
        sidebarVisible = UserDefaults.standard.object(forKey: Self.sidebarKey) as? Bool ?? true
        inspectorVisible = UserDefaults.standard.bool(forKey: Self.inspectorKey)

        connectionStore.$profiles
            .sink { [weak self] userProfiles in
                self?.profiles = ConnectionProfile.managedProfiles + userProfiles
            }
            .store(in: &cancellables)

        reachability.$statuses
            .sink { [weak self] statuses in
                self?.engineStatuses = statuses
            }
            .store(in: &cancellables)
    }

    public func status(for profileID: UUID) -> ServerStatus {
        engineStatuses[profileID] ?? .connecting
    }

    public func cachedObjects(for key: SchemaKey) -> [TableInfo]? {
        schemaCache[key]?.objects
    }

    public func cache(objects: [TableInfo], for key: SchemaKey) {
        schemaCache[key] = SchemaSnapshot(objects: objects)
    }

    /// Trả cache nếu có; miss thì nạp qua loader rồi cache.
    @discardableResult
    public func schema(for key: SchemaKey) async throws -> SchemaSnapshot {
        if let hit = schemaCache[key] { return hit }
        let objects = try await objectLoader(key)
        let snapshot = SchemaSnapshot(objects: objects)
        schemaCache[key] = snapshot
        return snapshot
    }

    public func invalidate(_ key: SchemaKey) {
        schemaCache[key] = nil
    }

    public func startPolling() {
        reachability.start(owner: "workspace")
    }

    public func stopPolling() {
        reachability.stop(owner: "workspace")
    }

    // MARK: Tabs

    public var activeSession: WorkspaceTabSession? {
        tabs.first { $0.id == activeTabID }
    }

    public var pendingChangeTotal: Int {
        tabs.reduce(0) { $0 + $1.vm.pendingChangeCount }
    }

    public var activeVM: DatabaseV2ViewModel? { activeSession?.vm }

    public func focusFilter() { filterFocusToken += 1 }

    public func requestBackups() { backupsRequest += 1 }

    public func requestNewDatabase() { newDatabaseRequest += 1 }

    public func requestDisconnect() { disconnectRequest += 1 }

    public func requestOpenConnection() { openConnectionRequest += 1 }

    /// DatabaseWindows đẩy profile vào cửa sổ đang mở; root quan sát token rồi nối.
    public func requestActivation(_ profileID: UUID) {
        activationProfileID = profileID
        activationToken += 1
    }

    /// ＋ Query từ toolbar: mở tab query cùng (profile, database) với tab đang mở.
    public func openQueryForActive() {
        guard let session = activeSession else { return }
        openQuery(profileID: session.kind.profileID, database: session.kind.database)
    }

    /// DB dropdown ở status pill: đổi database của tab đang mở.
    public func selectDatabaseForActive(_ name: String) {
        guard let vm = activeVM, vm.selectedDatabase != name else { return }
        Task { await vm.select(database: name) }
    }

    /// Refresh từ toolbar: nạp lại cửa sổ dòng hiện tại và bỏ cache schema của tab đang mở.
    public func refreshActive() {
        guard let session = activeSession else { return }
        let kind = session.kind
        session.touch()
        Task { await session.vm.reloadLoaded() }
        if !kind.isQuery {
            invalidate(SchemaKey(profileID: kind.profileID, database: kind.database))
        }
    }

    /// Single-click: nếu đã có tab đúng object thì kích hoạt; nếu tab hiện tại chưa staged và cùng
    /// (profile, database) thì preview vào đó; ngược lại (hoặc double-click) mở tab mới.
    public func openTable(_ table: TableInfo, profileID: UUID, database: String, forceNewTab: Bool) {
        guard let profile = profiles.first(where: { $0.id == profileID }) else { return }
        let target = WorkspaceTab.table(profileID: profileID, database: database, table: table)
        if let existing = tabs.first(where: { $0.kind == target }) {
            activate(existing.id)
            return
        }
        if !forceNewTab, let active = activeSession, active.vm.pendingChangeCount == 0,
           !active.kind.isQuery, active.kind.profileID == profileID, active.kind.database == database
        {
            active.retarget(target)
            active.vm.select(table: table)
            active.touch()
            return
        }
        guard let make = makeViewModel else { return }
        let session = WorkspaceTabSession(kind: target, vm: make(), idleInterval: tabIdleInterval)
        tabs.append(session)
        activeTabID = session.id
        session.touch()
        Task { await connect(session, profile: profile, database: database, table: table) }
    }

    public func openQuery(profileID: UUID, database: String) {
        guard let profile = profiles.first(where: { $0.id == profileID }), let make = makeViewModel else { return }
        let target = WorkspaceTab.query(profileID: profileID, database: database, id: UUID())
        let session = WorkspaceTabSession(kind: target, vm: make(), idleInterval: tabIdleInterval)
        tabs.append(session)
        activeTabID = session.id
        session.touch()
        Task { await connect(session, profile: profile, database: database, table: nil) }
    }

    public func activate(_ id: UUID) {
        activeTabID = id
        guard let session = tabs.first(where: { $0.id == id }) else { return }
        session.touch()
        if session.vm.isSuspended { Task { await session.resume() } }
    }

    @discardableResult
    public func closeTab(_ id: UUID, force: Bool = false) -> TabCloseOutcome {
        guard let idx = tabs.firstIndex(where: { $0.id == id }) else { return .closed }
        let session = tabs[idx]
        if !force, session.vm.pendingChangeCount > 0 {
            return .needsConfirmation(session.vm.pendingChangeCount)
        }
        session.cancelIdle()
        let vm = session.vm
        Task { await vm.disconnect() }
        tabs.remove(at: idx)
        if activeTabID == id {
            activeTabID = tabs.indices.contains(idx) ? tabs[idx].id : tabs.last?.id
        }
        return .closed
    }

    /// Đóng cửa sổ: ngắt và bỏ mọi tab.
    public func closeAll() {
        for session in tabs {
            session.cancelIdle()
            let vm = session.vm
            Task { await vm.disconnect() }
        }
        tabs = []
        activeTabID = nil
    }

    /// Sau DDL apply thành công: bỏ cache schema rồi nạp lại cho sidebar.
    public func refreshSchema(profileID: UUID, database: String) {
        let key = SchemaKey(profileID: profileID, database: database)
        invalidate(key)
        Task { _ = try? await schema(for: key) }
    }

    private func connect(
        _ session: WorkspaceTabSession, profile: ConnectionProfile, database: String, table: TableInfo?
    ) async {
        let interval = workspaceSignposter.beginInterval("open-tab")
        defer { workspaceSignposter.endInterval("open-tab", interval) }
        await session.vm.connect(profile: profile)
        guard case .connected = session.vm.connectionState else { return }
        if session.vm.selectedDatabase != database,
           session.vm.databases.contains(where: { $0.name == database })
        {
            await session.vm.select(database: database)
        }
        if let table { session.vm.select(table: table) }
        session.touch()
    }
}

public enum TabCloseOutcome: Equatable {
    case closed
    case needsConfirmation(Int)
}
