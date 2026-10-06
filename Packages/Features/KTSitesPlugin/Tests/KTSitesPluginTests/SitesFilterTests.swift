import Foundation
import KTPlatformContracts
@testable import KTSitesPlugin
import XCTest

final class SitesFilterTests: XCTestCase {
    private let shop = makeSite(name: "shop", domain: "shop.test", kind: .php)
    private let blog = makeSite(name: "blog", domain: "blog.test", kind: .php)
    private let app = makeSite(name: "app", domain: "app.test", kind: .node)
    private let api = makeSite(name: "api", domain: "backend.test", kind: .proxy)

    private var all: [SiteSummary] { [shop, blog, app, api] }

    func testKindAndQueryCombine() {
        let visible = SitesFilter.visible(all, kind: .php, query: "sho")
        XCTAssertEqual(visible.map(\.id), [shop.id])
    }

    func testQueryMatchesNameOrDomainAndKeepsOrder() {
        XCTAssertEqual(SitesFilter.visible(all, kind: nil, query: "backend").map(\.id), [api.id])
        XCTAssertEqual(SitesFilter.visible(all, kind: nil, query: "  .TEST ").map(\.id), all.map(\.id))
    }

    func testQueryMatchesPHPVersionOfPHPSitesOnly() {
        let legacy = makeSite(name: "legacy", domain: "legacy.test", phpVersion: "7.4", kind: .php)
        let sites = all + [legacy]
        XCTAssertEqual(SitesFilter.visible(sites, kind: nil, query: "php 7.4").map(\.id), [legacy.id])
        XCTAssertEqual(SitesFilter.visible(sites, kind: nil, query: "7.4").map(\.id), [legacy.id])
        XCTAssertEqual(SitesFilter.visible(sites, kind: nil, query: "PHP 8.4").map(\.id), [shop.id, blog.id])
    }

    func testWhitespaceQueryReturnsEverything() {
        XCTAssertEqual(SitesFilter.visible(all, kind: nil, query: " \n\t ").map(\.id), all.map(\.id))
    }

    func testCountsIgnoreKindFilter() {
        let counts = SitesFilter.counts(all, query: "b")
        XCTAssertEqual(counts[nil], 2)
        XCTAssertEqual(counts[.php], 1)
        XCTAssertEqual(counts[.proxy], 1)
        XCTAssertEqual(counts[.node] ?? 0, 0)
        let perKind = SiteKind.allCases.map { counts[$0] ?? 0 }.reduce(0, +)
        XCTAssertEqual(perKind, counts[nil])
    }

    func testReconcileKeepsVisibleSelection() {
        let ids = [UUID(), UUID(), UUID()]
        XCTAssertEqual(SitesFilter.reconcile(selected: ids[1], previous: ids, visible: ids), ids[1])
    }

    func testReconcilePicksNeighbourWhenRemoved() {
        let (first, second, third) = (UUID(), UUID(), UUID())
        XCTAssertEqual(SitesFilter.reconcile(selected: second, previous: [first, second, third], visible: [first, third]), third)
    }

    func testReconcilePicksLastWhenTailRemoved() {
        let (first, second, third) = (UUID(), UUID(), UUID())
        XCTAssertEqual(SitesFilter.reconcile(selected: third, previous: [first, second, third], visible: [first, second]), second)
    }

    func testReconcileEmptyReturnsNil() {
        let first = UUID()
        XCTAssertNil(SitesFilter.reconcile(selected: first, previous: [first], visible: []))
    }

    func testReconcileNilSelectsFirst() {
        let (first, second) = (UUID(), UUID())
        XCTAssertEqual(SitesFilter.reconcile(selected: nil, previous: [], visible: [first, second]), first)
    }
}
