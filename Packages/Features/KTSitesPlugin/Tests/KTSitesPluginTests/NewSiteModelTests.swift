import KTPlatformContracts
import XCTest
@testable import KTSitesPlugin

@MainActor
final class NewSiteModelTests: XCTestCase {
    private func makeModel(open: @escaping (URL) -> Void = { _ in }) -> (NewSiteModel, FakeSiteProvisioning) {
        let provisioning = FakeSiteProvisioning()
        let catalog = FakeSiteCatalog(catalog: SiteCatalogState(sites: [], tld: "test"))
        let model = NewSiteModel(provisioning: provisioning, catalog: catalog, open: open)
        return (model, provisioning)
    }

    func testInstallForwardsEventsFromProvisioning() async {
        let (model, provisioning) = makeModel()
        provisioning.installResult = .success(makeSite(name: "blog", domain: "blog.test"))
        let request = NewSiteRequest(
            name: "blog", kind: .empty, phpVersion: "8.4",
            folder: URL(fileURLWithPath: "/sites/blog"), domain: "blog.test", databaseName: nil
        )

        await model.install(request: request, openOnFinish: false, enableHTTPS: true).value

        XCTAssertFalse(model.events.isEmpty)
        XCTAssertTrue(model.finished)
        XCTAssertNil(model.error)
    }

    func testInstallSurfacesError() async {
        let (model, provisioning) = makeModel()
        provisioning.installResult = .failure(InstallError.folderExists("blog"))
        let request = NewSiteRequest(
            name: "blog", kind: .empty, phpVersion: "8.4",
            folder: URL(fileURLWithPath: "/sites/blog"), domain: "blog.test", databaseName: nil
        )

        await model.install(request: request, openOnFinish: false, enableHTTPS: true).value

        XCTAssertNotNil(model.error)
        XCTAssertFalse(model.finished)
    }

    func testInstallOpensOnFinishWhenRequested() async {
        var opened: URL?
        let (model, provisioning) = makeModel(open: { opened = $0 })
        provisioning.installResult = .success(makeSite(name: "blog", domain: "blog.test", secure: true))
        let request = NewSiteRequest(
            name: "blog", kind: .empty, phpVersion: "8.4",
            folder: URL(fileURLWithPath: "/sites/blog"), domain: "blog.test", databaseName: nil
        )

        await model.install(request: request, openOnFinish: true, enableHTTPS: true).value

        XCTAssertEqual(opened, URL(string: "https://blog.test/"))
    }

    func testImportExistingSurfacesError() async {
        let (model, provisioning) = makeModel()
        provisioning.importResult = .failure(SiteImportError.alreadyRegistered("blog"))

        await model.importExisting(
            folder: URL(fileURLWithPath: "/sites/blog"), domain: "blog.test", phpVersion: "8.4",
            createDatabase: false, enableHTTPS: true, openOnFinish: false
        ).value

        XCTAssertNotNil(model.error)
        XCTAssertFalse(model.finished)
    }

    func testResetClearsState() async {
        let (model, provisioning) = makeModel()
        provisioning.installResult = .failure(InstallError.folderExists("blog"))
        let request = NewSiteRequest(
            name: "blog", kind: .empty, phpVersion: "8.4",
            folder: URL(fileURLWithPath: "/sites/blog"), domain: "blog.test", databaseName: nil
        )
        await model.install(request: request, openOnFinish: false, enableHTTPS: true).value
        XCTAssertNotNil(model.error)

        model.reset()

        XCTAssertNil(model.error)
        XCTAssertFalse(model.finished)
        XCTAssertFalse(model.installing)
        XCTAssertTrue(model.events.isEmpty)
    }
}
