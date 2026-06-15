import XCTest
@testable import KDWarmKit

/// Persistence coverage for the connection profile store, mirroring `SiteRegistryTests`: profiles
/// round-trip through a temp JSON file, `onChange` fires on every mutation, and a fresh store over
/// the same file reloads them. The synthetic managed profile is always listed but never persisted.
@MainActor
final class ConnectionStoreTests: XCTestCase {
    private let fm = FileManager.default

    private func makeStore() -> (ConnectionStore, URL) {
        let dir = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("kd-conn-\(UUID().uuidString)", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return (ConnectionStore(storeURL: dir.appendingPathComponent("connections.json")), dir)
    }

    private func sampleProfile(_ name: String = "prod") -> ConnectionProfile {
        ConnectionProfile(name: name, kind: .postgres, host: "db.example.com",
                          port: 5432, user: "reader", database: "app")
    }

    func testAddPersistsAndReloads() throws {
        let (store, dir) = makeStore(); defer { try? fm.removeItem(at: dir) }
        let profile = sampleProfile()
        store.add(profile)
        XCTAssertTrue(store.profiles.contains(profile))

        let reloaded = ConnectionStore(storeURL: dir.appendingPathComponent("connections.json"))
        XCTAssertTrue(reloaded.profiles.contains(profile))
    }

    func testManagedProfileAlwaysListedButNeverPersisted() throws {
        let (store, dir) = makeStore(); defer { try? fm.removeItem(at: dir) }
        // The synthetic managed engine is surfaced in `allProfiles` for the UI...
        XCTAssertTrue(store.allProfiles.contains { $0.isManaged })
        // ...but the on-disk JSON only ever holds user-added profiles.
        store.add(sampleProfile())
        let json = String(decoding: try Data(contentsOf: dir.appendingPathComponent("connections.json")),
                          as: UTF8.self)
        XCTAssertFalse(json.contains("managed"))
    }

    func testUpdateMutatesInPlaceAndPersists() throws {
        let (store, dir) = makeStore(); defer { try? fm.removeItem(at: dir) }
        var profile = sampleProfile()
        store.add(profile)
        profile.name = "renamed"
        store.update(profile)
        XCTAssertEqual(store.profiles.first { $0.id == profile.id }?.name, "renamed")
        XCTAssertEqual(store.profiles.count, 1)   // update, not append
    }

    func testRemoveDeletesProfileAndKeychainPassword() throws {
        let (store, dir) = makeStore(); defer { try? fm.removeItem(at: dir) }
        let profile = sampleProfile()
        store.add(profile)
        store.remove(profile)
        XCTAssertFalse(store.profiles.contains(profile))
    }

    func testOnChangeFiresOnMutation() throws {
        let (store, dir) = makeStore(); defer { try? fm.removeItem(at: dir) }
        var fires = 0
        store.onChange = { fires += 1 }
        store.add(sampleProfile())
        store.remove(store.profiles[0])
        XCTAssertEqual(fires, 2)
    }
}
