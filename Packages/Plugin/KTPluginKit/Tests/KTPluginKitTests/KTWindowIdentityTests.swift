import XCTest
@testable import KTPluginKit

final class KTWindowIdentityTests: XCTestCase {
    func testMatchesSceneIdentifierEvenWhenTitleIsBlank() {
        XCTAssertTrue(KTWindowIdentity.matches("dashboard", sceneID: "dashboard"))
        XCTAssertTrue(KTWindowIdentity.matches("dashboard-AppWindow-1", sceneID: "dashboard"))
        XCTAssertFalse(KTWindowIdentity.matches("dashboards", sceneID: "dashboard"))
        XCTAssertFalse(KTWindowIdentity.matches(nil, sceneID: "dashboard"))
    }

    func testMinimizedWindowKeepsAppInDock() {
        XCTAssertTrue(KTWindowIdentity.keepsAppInDock(isVisible: false, isMiniaturized: true, canBecomeMain: true, isPanel: false))
        XCTAssertFalse(KTWindowIdentity.keepsAppInDock(isVisible: false, isMiniaturized: false, canBecomeMain: true, isPanel: false))
        XCTAssertFalse(KTWindowIdentity.keepsAppInDock(isVisible: true, isMiniaturized: false, canBecomeMain: true, isPanel: true))
    }

    @MainActor
    func testFindsWindowByIdentifierAfterChromeClearsTitle() {
        let window = NSWindow(contentRect: .zero, styleMask: [.titled], backing: .buffered, defer: true)
        window.identifier = NSUserInterfaceItemIdentifier("dashboard-AppWindow-1")
        window.title = ""
        XCTAssertTrue(KTWindowIdentity.window(sceneID: "dashboard", in: [window]) === window)
    }
}
