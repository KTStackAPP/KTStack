import KTPlatformContracts
import XCTest
@testable import KTServicesPlugin

final class ServicesBannerBuilderTests: XCTestCase {
    private func dns(
        _ status: DNSResolverStatus,
        lastError: String? = nil,
        usesHelper: Bool = false,
        helperNeedsApproval: Bool = false
    ) -> DNSResolverState {
        DNSResolverState(
            status: status, isBusy: false, lastError: lastError,
            usesHelper: usesHelper, helperNeedsApproval: helperNeedsApproval
        )
    }

    private var noopActions: ServiceBannerActions {
        ServiceBannerActions(
            onEnableDNS: {}, onResetDNS: {}, onOpenTLSSettings: {}, onOpenLoginItems: {}, onRestart: { _ in }
        )
    }

    private func build(
        services: [ServiceState] = [],
        dns: DNSResolverState,
        ca: CATrustState = CATrustState(exists: true, trusted: true),
        actions: ServiceBannerActions? = nil
    ) -> [ServiceBanner] {
        ServicesBannerBuilder.banners(services: services, dns: dns, ca: ca, actions: actions ?? noopActions)
    }

    func testConflictBanner() {
        let banners = build(dns: dns(.conflict("named")))
        XCTAssertEqual(banners.first?.id, "dns-conflict")
        XCTAssertEqual(banners.first?.title, "DNS port is in use")
        XCTAssertEqual(banners.first?.ctaTitle, "Reset DNS")
    }

    func testErrorNeedsApprovalOpensLoginItems() {
        let banners = build(dns: dns(.disabled, lastError: "boom", usesHelper: true, helperNeedsApproval: true))
        XCTAssertEqual(banners.first?.id, "dns-error")
        XCTAssertEqual(banners.first?.ctaTitle, "Open Login Items")
    }

    func testErrorNoApprovalTryAgain() {
        let banners = build(dns: dns(.disabled, lastError: "boom", usesHelper: false, helperNeedsApproval: false))
        XCTAssertEqual(banners.first?.id, "dns-error")
        XCTAssertEqual(banners.first?.ctaTitle, "Try again")
    }

    func testApproveBannerWhenDisabledAndNeedsApproval() {
        let banners = build(dns: dns(.disabled, helperNeedsApproval: true))
        XCTAssertEqual(banners.first?.id, "dns-approve")
        XCTAssertEqual(banners.first?.ctaTitle, "Open Login Items")
    }

    func testDisabledCleanShowsDNSOff() {
        let banners = build(dns: dns(.disabled))
        XCTAssertEqual(banners.first?.id, "dns-off")
        XCTAssertEqual(banners.first?.ctaTitle, "Enable DNS")
    }

    func testCAUntrustedBanner() {
        let banners = build(dns: dns(.enabled), ca: CATrustState(exists: true, trusted: false))
        XCTAssertTrue(banners.contains { $0.id == "ca-untrusted" })
    }

    func testServiceErrorBannerCallsRestart() throws {
        var restarted: ServiceID?
        let actions = ServiceBannerActions(
            onEnableDNS: {}, onResetDNS: {}, onOpenTLSSettings: {}, onOpenLoginItems: {},
            onRestart: { restarted = $0 }
        )
        let banners = build(
            services: [makeState(.mysql, health: .error)],
            dns: dns(.enabled),
            actions: actions
        )
        let banner = try XCTUnwrap(banners.first { $0.id == "error-mysql" })
        XCTAssertEqual(banner.ctaTitle, "Restart")
        banner.action?()
        XCTAssertEqual(restarted, .mysql)
    }

    func testNotAvailableBanner() throws {
        let banners = build(
            services: [makeState(.mongodb, isInstalled: false, installable: false)],
            dns: dns(.enabled)
        )
        let banner = try XCTUnwrap(banners.first { $0.id == "not-available" })
        XCTAssertTrue(banner.message.contains("mongodb"))
    }

    func testAllHealthyNoBanners() {
        let banners = build(
            services: [makeState(.nginx, health: .running)],
            dns: dns(.enabled),
            ca: CATrustState(exists: true, trusted: true)
        )
        XCTAssertTrue(banners.isEmpty)
    }
}
