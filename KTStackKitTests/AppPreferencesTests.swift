import KTStackCore
import XCTest
@testable import KTStackKit

@MainActor
final class AppPreferencesTests: XCTestCase {
    /// A throwaway UserDefaults domain per test so the round-trip never touches `.standard`.
    private func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: "ktstack-prefs-\(UUID().uuidString)")!
    }

    func testDefaultsWhenUnset() {
        let prefs = AppPreferences(defaults: makeDefaults())
        XCTAssertEqual(prefs.tld, AppPreferences.defaultTLD)
        XCTAssertEqual(prefs.sitesRootPath, AppPreferences.defaultSitesRootPath)
    }

    func testTLDPersistsAndReloads() {
        let d = makeDefaults()
        XCTAssertTrue(AppPreferences(defaults: d).setTLD("home.arpa"))
        XCTAssertEqual(AppPreferences(defaults: d).tld, "home.arpa") // fresh instance reloads it
    }

    func testSitesRootPersistsAndReloads() {
        let d = makeDefaults()
        AppPreferences(defaults: d).setSitesRootPath("/tmp/MySites")
        XCTAssertEqual(AppPreferences(defaults: d).sitesRootPath, "/tmp/MySites")
    }

    func testInvalidTLDRejectedAndNothingPersisted() {
        let prefs = AppPreferences(defaults: makeDefaults())
        XCTAssertFalse(prefs.setTLD("My.Test")) // uppercase
        XCTAssertFalse(prefs.setTLD("a b")) // space
        XCTAssertFalse(prefs.setTLD(".test")) // leading dot
        XCTAssertFalse(prefs.setTLD("a..b")) // empty label
        XCTAssertFalse(prefs.setTLD("")) // empty
        XCTAssertEqual(prefs.tld, AppPreferences.defaultTLD) // unchanged
    }

    func testValidatorAcceptsEverySafeTLD() {
        for tld in AppPreferences.safeTLDs {
            XCTAssertTrue(AppPreferences.isValidTLD(tld), "\(tld) should validate")
        }
    }

    func testCorruptStoredTLDFallsBackToDefault() {
        let d = makeDefaults()
        d.set("Bad Value", forKey: "KTStack.tld")
        XCTAssertEqual(AppPreferences(defaults: d).tld, AppPreferences.defaultTLD)
    }

    func testSafeListExcludesHSTSAndPublicTLDs() {
        XCTAssertFalse(AppPreferences.safeTLDs.contains("dev")) // HSTS-preloaded
        XCTAssertFalse(AppPreferences.safeTLDs.contains("com")) // real public TLD
    }

    func testHSTSPreloadedTLDsAreFlagged() {
        XCTAssertTrue(DNSConstants.isHSTSPreloaded("dev"))
        XCTAssertTrue(DNSConstants.isHSTSPreloaded("app"))
        XCTAssertTrue(DNSConstants.isHSTSPreloaded("corp.dev"))
        for tld in AppPreferences.safeTLDs {
            XCTAssertFalse(DNSConstants.isHSTSPreloaded(tld), "\(tld) is not preloaded")
        }
        XCTAssertFalse(DNSConstants.isHSTSPreloaded("devs"))
    }

    func testReservedTLDReason() {
        for name in ["local", "localhost", "foo.local"] {
            XCTAssertNotNil(DNSConstants.reservedTLDReason(name), name)
        }
        for name in ["test", "dev", "locals"] {
            XCTAssertNil(DNSConstants.reservedTLDReason(name), name)
        }
    }
}
