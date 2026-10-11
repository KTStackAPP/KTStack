import SwiftUI
import XCTest
@testable import KTDatabasePlugin

@MainActor
final class WorkspaceTabHostControllerTests: XCTestCase {
    private var built: [UUID] = []

    private func show(_ controller: WorkspaceTabHostController, _ id: UUID, live: [UUID]) {
        controller.show(activeID: id, liveIDs: Set(live)) { id in
            self.built.append(id)
            return AnyView(Text(id.uuidString))
        }
    }

    private func visibleCount(_ controller: WorkspaceTabHostController) -> Int {
        controller.view.subviews.filter { !$0.isHidden }.count
    }

    func testSwitchingBackReusesHostAndShowsOnlyActive() {
        let controller = WorkspaceTabHostController(limit: 8)
        let a = UUID(), b = UUID()
        show(controller, a, live: [a, b])
        show(controller, b, live: [a, b])
        show(controller, a, live: [a, b])
        XCTAssertEqual(built, [a, b])
        XCTAssertEqual(controller.view.subviews.count, 2)
        XCTAssertEqual(visibleCount(controller), 1)
    }

    func testClosedTabDropsItsHost() {
        let controller = WorkspaceTabHostController(limit: 8)
        let a = UUID(), b = UUID()
        show(controller, a, live: [a, b])
        show(controller, b, live: [a, b])
        show(controller, b, live: [b])
        XCTAssertEqual(controller.view.subviews.count, 1)
        XCTAssertEqual(controller.children.count, 1)
    }

    func testEvictedTabIsRebuiltOnReturn() {
        let controller = WorkspaceTabHostController(limit: 2)
        let a = UUID(), b = UUID(), c = UUID()
        let live = [a, b, c]
        show(controller, a, live: live)
        show(controller, b, live: live)
        show(controller, c, live: live)
        XCTAssertEqual(controller.view.subviews.count, 2)
        show(controller, a, live: live)
        XCTAssertEqual(built, [a, b, c, a])
        XCTAssertEqual(visibleCount(controller), 1)
    }
}
