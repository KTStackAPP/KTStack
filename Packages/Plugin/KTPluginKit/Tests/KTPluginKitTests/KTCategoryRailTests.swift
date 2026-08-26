import SwiftUI
import XCTest
@testable import KTPluginKit

final class KTCategoryRailTests: XCTestCase {
    private enum Cat: Hashable { case php, node, mysql }

    func testItemIdentityMatchesID() {
        let item = KTCategoryRailItem(
            id: Cat.php, title: "PHP", summary: "7 installed", systemImage: "x", tint: KTIconTint.php
        )
        XCTAssertEqual(item.id, .php)
        XCTAssertNil(item.dot)
    }

    func testSectionHoldsItemsInOrder() {
        let section = KTCategoryRailSection(id: "LANGUAGES", items: [
            KTCategoryRailItem(id: Cat.php, title: "PHP", summary: "", systemImage: "x", tint: KTIconTint.php),
            KTCategoryRailItem(id: Cat.node, title: "Node", summary: "", systemImage: "y", tint: KTIconTint.cube),
        ])
        XCTAssertEqual(section.id, "LANGUAGES")
        XCTAssertEqual(section.items.map(\.id), [.php, .node])
    }

    func testRailBuildsInBothWidthModes() {
        let sections = [
            KTCategoryRailSection(id: "DB", items: [
                KTCategoryRailItem(id: Cat.mysql, title: "MySQL", summary: "8.4 active", systemImage: "z", tint: KTIconTint.db, dot: KTColor.runDot),
            ]),
        ]
        var sel = Cat.mysql
        let binding = Binding(get: { sel }, set: { sel = $0 })
        _ = KTCategoryRail(sections: sections, selection: binding, compact: false).body
        _ = KTCategoryRail(sections: sections, selection: binding, compact: true).body
    }
}
