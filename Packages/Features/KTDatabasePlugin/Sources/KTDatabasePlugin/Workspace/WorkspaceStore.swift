import Combine
import Foundation

/// Gom trạng thái cửa sổ workspace: danh sách profile (đồng bộ ConnectionStore), chấm engine
/// (mirror ServerReachabilityService), cache schema theo (profile, database), profile/db đang chọn.
@MainActor
public final class WorkspaceStore: ObservableObject {
    @Published public private(set) var profiles: [ConnectionProfile] = []
    @Published public private(set) var engineStatuses: [UUID: ServerStatus] = [:]
    @Published public private(set) var schemaCache: [SchemaKey: SchemaSnapshot] = [:]
    @Published public var selectedProfileID: UUID?
    @Published public var activeDatabase: String?

    public let recentStore: RecentObjectStore

    private let reachability: ServerReachabilityService
    private let objectLoader: (SchemaKey) async throws -> [TableInfo]
    private var cancellables: Set<AnyCancellable> = []

    public init(
        connectionStore: ConnectionStore,
        reachability: ServerReachabilityService,
        recentStore: RecentObjectStore,
        objectLoader: @escaping (SchemaKey) async throws -> [TableInfo]
    ) {
        self.reachability = reachability
        self.recentStore = recentStore
        self.objectLoader = objectLoader

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
}
