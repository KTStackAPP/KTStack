import KTPlatformContracts
import XCTest
@testable import KTServicesPlugin

@MainActor
final class NginxIncludeEditorModelTests: XCTestCase {
    func testRejectedMapsToRejectedMessage() async {
        let fake = FakeNginxInclude()
        fake.saveError = .rejected("bad directive")
        let model = NginxIncludeEditorModel(nginxInclude: fake)
        model.text = "new"
        let ok = await model.save()
        XCTAssertFalse(ok)
        XCTAssertTrue(model.errorMessage?.contains("nginx rejected the config") ?? false)
        XCTAssertTrue(model.errorMessage?.contains("bad directive") ?? false)
    }

    func testCouldNotValidateMessage() async {
        let fake = FakeNginxInclude()
        fake.saveError = .couldNotValidate
        let model = NginxIncludeEditorModel(nginxInclude: fake)
        let ok = await model.save()
        XCTAssertFalse(ok)
        XCTAssertTrue(model.errorMessage?.contains("Could not validate") ?? false)
    }

    func testReloadFailedRevertedMessage() async {
        let fake = FakeNginxInclude()
        fake.saveError = .reloadFailedReverted("kaboom")
        let model = NginxIncludeEditorModel(nginxInclude: fake)
        let ok = await model.save()
        XCTAssertFalse(ok)
        XCTAssertTrue(model.errorMessage?.contains("reload failed") ?? false)
        XCTAssertTrue(model.errorMessage?.contains("kaboom") ?? false)
    }

    func testSuccessReturnsTrueNoError() async {
        let fake = FakeNginxInclude()
        let model = NginxIncludeEditorModel(nginxInclude: fake)
        model.text = "good"
        let ok = await model.save()
        XCTAssertTrue(ok)
        XCTAssertNil(model.errorMessage)
        XCTAssertEqual(fake.savedContents, ["good"])
    }

    func testResetDoesNotSave() {
        let fake = FakeNginxInclude(defaultInclude: "TEMPLATE")
        let model = NginxIncludeEditorModel(nginxInclude: fake)
        model.reset()
        XCTAssertEqual(model.text, "TEMPLATE")
        XCTAssertTrue(fake.savedContents.isEmpty)
    }

    func testLoadFallsBackToTemplateWhenReadThrows() {
        let fake = FakeNginxInclude(defaultInclude: "TEMPLATE")
        fake.readShouldThrow = true
        let model = NginxIncludeEditorModel(nginxInclude: fake)
        model.load()
        XCTAssertEqual(model.text, "TEMPLATE")
    }
}
