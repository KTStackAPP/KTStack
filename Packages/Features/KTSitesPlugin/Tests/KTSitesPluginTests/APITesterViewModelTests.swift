import KTPlatformContracts
import XCTest
@testable import KTSitesPlugin

@MainActor
final class APITesterViewModelTests: XCTestCase {
    private func makeTempSiteFolder(laravel: Bool) throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        if laravel {
            FileManager.default.createFile(atPath: folder.appendingPathComponent("artisan").path, contents: Data())
        }
        return folder
    }

    func testLoadLaravelSiteUsesRouteIntrospectionContract() async throws {
        let folder = try makeTempSiteFolder(laravel: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let introspecting = FakeAPIRouteIntrospecting()
        let route = APIRoute(method: "GET", uri: "/api/users", name: "users.index", middleware: ["api"], action: "", fields: [], rulesResolved: true)
        introspecting.result = .success(RouteIntrospectionOutcome(routes: [route], metadataOnly: false, warning: nil))
        let vm = APITesterViewModel(routeIntrospection: introspecting)
        let site = makeSite(path: folder.path, domain: "laravel.test")

        await vm.load(site: site)

        XCTAssertTrue(vm.showsTabs)
        XCTAssertEqual(vm.routes, [route])
        XCTAssertEqual(introspecting.calls.first?.1, "8.4")
    }

    func testLoadLaravelSiteSurfacesMetadataOnlyWarning() async throws {
        let folder = try makeTempSiteFolder(laravel: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let introspecting = FakeAPIRouteIntrospecting()
        introspecting.result = .success(RouteIntrospectionOutcome(routes: [], metadataOnly: true, warning: "PHP execution unavailable"))
        let vm = APITesterViewModel(routeIntrospection: introspecting)

        await vm.load(site: makeSite(path: folder.path))

        XCTAssertEqual(vm.metadataWarning, "PHP execution unavailable")
    }

    func testLoadNonLaravelSiteFallsBackToGenericDiscovery() async throws {
        let folder = try makeTempSiteFolder(laravel: false)
        defer { try? FileManager.default.removeItem(at: folder) }
        let introspecting = FakeAPIRouteIntrospecting()
        let vm = APITesterViewModel(routeIntrospection: introspecting)

        await vm.load(site: makeSite(path: folder.path))

        XCTAssertFalse(vm.showsTabs)
        XCTAssertTrue(introspecting.calls.isEmpty)
    }

    func testResolvedInterpolatesVariablesBeforeSend() {
        let vm = APITesterViewModel(routeIntrospection: FakeAPIRouteIntrospecting())
        vm.variables = [EditablePair(key: "token", value: "abc123", enabled: true)]

        XCTAssertEqual(vm.resolved("Bearer {{token}}"), "Bearer abc123")
    }

    func testResolvedSkipsDisabledVariables() {
        let vm = APITesterViewModel(routeIntrospection: FakeAPIRouteIntrospecting())
        vm.variables = [EditablePair(key: "token", value: "abc123", enabled: false)]

        XCTAssertEqual(vm.resolved("Bearer {{token}}"), "Bearer {{token}}")
    }

    func testBuildSpecAppliesVariableInterpolationToHeaders() throws {
        let vm = APITesterViewModel(routeIntrospection: FakeAPIRouteIntrospecting())
        vm.variables = [EditablePair(key: "token", value: "abc123", enabled: true)]
        let route = APIRoute(method: "GET", uri: "/users", name: nil, middleware: [], action: "", fields: [], rulesResolved: true)
        vm.select(route)
        vm.requestDraft.headers = [EditablePair(key: "Authorization", value: "Bearer {{token}}", enabled: true)]

        let spec = try vm.buildSpec(route: route, site: makeSite(domain: "example.test"))

        XCTAssertTrue(spec.headers.contains { $0.0 == "Authorization" && $0.1 == "Bearer abc123" })
    }
}
