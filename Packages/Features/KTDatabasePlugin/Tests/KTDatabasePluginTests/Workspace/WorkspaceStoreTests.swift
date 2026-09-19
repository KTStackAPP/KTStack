import KTStackCore
import XCTest
@testable import KTDatabasePlugin

@MainActor
final class WorkspaceStoreTests: XCTestCase {
    private let fm = FileManager.default

    private final class LoadCounter { var count = 0 }

    private func makeStore(loader: @escaping (SchemaKey) async throws -> [TableInfo])
        -> (WorkspaceStore, ConnectionStore, URL)
    {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("kd-ws-\(UUID().uuidString)", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        let connectionStore = ConnectionStore(
            storeURL: dir.appendingPathComponent("connections.json"),
            keychain: KeychainStore(service: "com.ktstack.db.tests")
        )
        let store = WorkspaceStore(
            connectionStore: connectionStore,
            reachability: ServerReachabilityService(),
            recentStore: RecentObjectStore(storeURL: dir.appendingPathComponent("recent.json")),
            objectLoader: loader
        )
        return (store, connectionStore, dir)
    }

    func testSchemaCachesOnMissAndReusesOnHit() async throws {
        let counter = LoadCounter()
        let (store, _, dir) = makeStore { _ in counter.count += 1; return [TableInfo(name: "users")] }
        defer { try? fm.removeItem(at: dir) }
        let key = SchemaKey(profileID: UUID(), database: "app")

        let first = try await store.schema(for: key)
        XCTAssertEqual(first.objects.map(\.name), ["users"])
        XCTAssertEqual(counter.count, 1)

        _ = try await store.schema(for: key)
        XCTAssertEqual(counter.count, 1)
    }

    func testInvalidateForcesReload() async throws {
        let counter = LoadCounter()
        let (store, _, dir) = makeStore { _ in counter.count += 1; return [] }
        defer { try? fm.removeItem(at: dir) }
        let key = SchemaKey(profileID: UUID(), database: "app")

        _ = try await store.schema(for: key)
        store.invalidate(key)
        _ = try await store.schema(for: key)
        XCTAssertEqual(counter.count, 2)
    }

    func testProfilesSyncFromConnectionStore() {
        let (store, connectionStore, dir) = makeStore { _ in [] }
        defer { try? fm.removeItem(at: dir) }

        XCTAssertEqual(store.profiles.count, ConnectionProfile.managedProfiles.count)
        let profile = ConnectionProfile(
            name: "prod", kind: .postgres, host: "db", port: 5432, user: "r", database: "app"
        )
        connectionStore.add(profile)
        XCTAssertTrue(store.profiles.contains(profile))
    }

    func testCacheHelpersRoundTrip() {
        let (store, _, dir) = makeStore { _ in [] }
        defer { try? fm.removeItem(at: dir) }
        let key = SchemaKey(profileID: UUID(), database: "app")
        XCTAssertNil(store.cachedObjects(for: key))
        store.cache(objects: [TableInfo(name: "users")], for: key)
        XCTAssertEqual(store.cachedObjects(for: key)?.map(\.name), ["users"])
        store.invalidate(key)
        XCTAssertNil(store.cachedObjects(for: key))
    }
}
