import SwiftUI
import XCTest
@testable import KTPluginKit

@MainActor
final class KTModalPresenterTests: XCTestCase {
    func testPresentSetsModal() {
        let presenter = KTModalPresenter()
        presenter.present(id: "a") { Text("A") }
        XCTAssertEqual(presenter.modal?.id, "a")
    }

    func testDismissClearsModal() {
        let presenter = KTModalPresenter()
        presenter.present(id: "a") { Text("A") }
        presenter.dismiss()
        XCTAssertNil(presenter.modal)
    }

    func testPresentSameIDReplacesContent() {
        let presenter = KTModalPresenter()
        presenter.present(id: "a") { Text("first") }
        presenter.present(id: "a") { Text("second") }
        XCTAssertEqual(presenter.modal?.id, "a")
    }

    func testPresentDifferentIDReplacesNotStacks() {
        let presenter = KTModalPresenter()
        presenter.present(id: "a") { Text("A") }
        presenter.present(id: "b") { Text("B") }
        XCTAssertEqual(presenter.modal?.id, "b")
    }
}
