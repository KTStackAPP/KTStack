import KTPlatformContracts
import XCTest
@testable import KTRuntimesPlugin

@MainActor
final class PHPPoolEditorModelTests: XCTestCase {
    func testLoadPullsSettingsFromConfig() {
        let fake = FakePHPConfig()
        var stored = PHPPoolSettings.default
        stored.maxChildren = 42
        fake.storedPool = stored
        let model = PHPPoolEditorModel(version: "8.4", phpConfig: fake)
        model.load()
        XCTAssertEqual(model.draft.maxChildren, 42)
    }

    func testValidationMessageWhenStartExceedsMaxSpare() {
        let model = PHPPoolEditorModel(version: "8.4", phpConfig: FakePHPConfig())
        model.draft.startServers = 9 // > maxSpareServers(3)
        XCTAssertNotNil(model.validationMessage)
        XCTAssertFalse(model.canSave)
    }

    func testSaveForwardsDraft() async {
        let fake = FakePHPConfig()
        let model = PHPPoolEditorModel(version: "8.4", phpConfig: fake)
        model.draft.maxChildren = 20
        let ok = await model.save()
        XCTAssertTrue(ok)
        XCTAssertEqual(fake.savedPool.count, 1)
        XCTAssertEqual(fake.savedPool.first?.0, "8.4")
        XCTAssertEqual(fake.savedPool.first?.1.maxChildren, 20)
    }

    func testSaveRejectedSetsErrorAndKeepsDraft() async {
        let fake = FakePHPConfig()
        fake.savePoolError = PHPPoolSaveError.rejected("bad conf")
        let model = PHPPoolEditorModel(version: "8.4", phpConfig: fake)
        model.draft.maxChildren = 33
        let ok = await model.save()
        XCTAssertFalse(ok)
        XCTAssertEqual(model.draft.maxChildren, 33)
        XCTAssertTrue(model.error?.contains("bad conf") ?? false)
    }

    func testResetGoesBackToDefault() {
        let model = PHPPoolEditorModel(version: "8.4", phpConfig: FakePHPConfig())
        model.draft.maxChildren = 99
        model.reset()
        XCTAssertEqual(model.draft, .default)
    }
}
