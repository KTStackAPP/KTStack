import KTPlatformContracts
import XCTest
@testable import KTSitesPlugin

final class SitesGroupFilterTests: XCTestCase {
    private let blog = makeSite(name: "blog", domain: "blog.test", group: "wordpress")
    private let shop = makeSite(name: "shop", domain: "shop.test", group: "Archive")
    private let api = makeSite(name: "api", domain: "api.test")
    private let docs = makeSite(name: "docs", domain: "docs.test", group: "Archive")
    private var all: [SiteSummary] { [blog, shop, api, docs] }

    func testSectionsSortNamedGroupsAndPutUngroupedLast() {
        let sections = SitesFilter.sections(all)
        XCTAssertEqual(sections.map(\.title), ["Archive", "wordpress", nil])
        XCTAssertEqual(sections[0].sites.map(\.id), [shop.id, docs.id])
        XCTAssertEqual(sections[2].sites.map(\.id), [api.id])
    }

    func testNobodyGroupedGivesOneUntitledSection() {
        let plain = [makeSite(name: "a"), makeSite(name: "b")]
        let sections = SitesFilter.sections(plain)
        XCTAssertEqual(sections.count, 1)
        XCTAssertNil(sections[0].title)
        XCTAssertEqual(sections[0].sites.map(\.id), plain.map(\.id))
    }

    func testEmptyInputGivesNoSections() {
        XCTAssertTrue(SitesFilter.sections([]).isEmpty)
    }

    func testGroupNamesAreDistinctAndSorted() {
        XCTAssertEqual(SitesFilter.groupNames(all), ["Archive", "wordpress"])
    }

    func testNamedFilterKeepsOnlyThatGroup() {
        let visible = SitesFilter.visible(all, kind: nil, group: .named("Archive"), query: "")
        XCTAssertEqual(visible.map(\.id), [shop.id, docs.id])
    }

    func testUngroupedFilterKeepsSitesWithoutGroup() {
        XCTAssertEqual(SitesFilter.visible(all, kind: nil, group: .ungrouped, query: "").map(\.id), [api.id])
    }

    func testSearchMatchesGroupName() {
        XCTAssertEqual(SitesFilter.visible(all, kind: nil, query: "archi").map(\.id), [shop.id, docs.id])
    }

    func testKindCountsFollowGroupFilter() {
        let counts = SitesFilter.counts(all, group: .named("Archive"), query: "")
        XCTAssertEqual(counts[nil], 2)
        XCTAssertEqual(counts[.php], 2)
    }
}
