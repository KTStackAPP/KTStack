import Foundation
import KTStackCore
import XCTest
@testable import KTStackKit

final class TunnelVhostDirectivesTests: XCTestCase {
    private let writer = NginxTunnelVhostWriter()

    private func phpSite() -> Site {
        Site(name: "App", path: "/site", docroot: "/site/public", domain: "app.test", phpVersion: "8.4", type: .php, secure: true)
    }

    func testTunnelVhostIncludesThePerSiteDirectives() {
        let directives = URL(fileURLWithPath: "/conf/directives/site.conf")
        let v = writer.vhost(
            site: phpSite(), port: 45123, phpFpmSocket: URL(fileURLWithPath: "/run/php.sock"),
            directivesInclude: directives
        )
        XCTAssertTrue(v.contains("include \"/conf/directives/site.conf\";"), v)
    }

    func testApacheSiteIsProxiedToItsBackendSoHtaccessApplies() {
        let v = writer.vhost(
            site: phpSite(), port: 45123, phpFpmSocket: URL(fileURLWithPath: "/run/php.sock"),
            publicHost: "abc.trycloudflare.com", supportsBodyRewrite: true, apacheBackendPort: 18042
        )
        XCTAssertTrue(v.contains("proxy_pass http://127.0.0.1:18042;"), v)
        XCTAssertTrue(v.contains("proxy_set_header Host abc.trycloudflare.com;"))
        XCTAssertTrue(v.contains("proxy_set_header X-Forwarded-Proto https;"))
        XCTAssertTrue(v.contains("proxy_set_header Accept-Encoding \"\";"))
        XCTAssertTrue(v.contains("sub_filter"))
        XCTAssertFalse(v.contains("fastcgi_pass"))
    }
}

final class ProcessWatchdogTests: XCTestCase {
    private func finishedPID() throws -> pid_t {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/true")
        try process.run()
        process.waitUntilExit()
        return process.processIdentifier
    }

    func testCommandLineRoundTrips() throws {
        let deadline = Date(timeIntervalSince1970: 2_000_000_000)
        let line = ProcessWatchdog.commandLine(
            parentPID: 4242, deadline: deadline, executable: URL(fileURLWithPath: "/bin/cf"), arguments: ["tunnel", "--url", "x"]
        )
        XCTAssertEqual(line.first, ProcessWatchdog.command)
        let parsed = try XCTUnwrap(ProcessWatchdog.parse(Array(line.dropFirst())))
        XCTAssertEqual(parsed.watchdog.parentPID, 4242)
        XCTAssertEqual(parsed.watchdog.deadline, deadline)
        XCTAssertEqual(parsed.executable, "/bin/cf")
        XCTAssertEqual(parsed.arguments, ["tunnel", "--url", "x"])
        XCTAssertNil(ProcessWatchdog.parse(["--parent-pid", "1", "--", "/bin/cf"]))
        XCTAssertNil(ProcessWatchdog.parse(["--parent-pid", "12"]))
    }

    func testChildIsStoppedWhenTheParentIsGone() throws {
        let watchdog = ProcessWatchdog(parentPID: try finishedPID(), deadline: nil, pollInterval: 0.1, gracePeriod: 1)
        let started = Date()
        _ = watchdog.run(executable: "/bin/sleep", arguments: ["30"], forwardTermination: false)
        XCTAssertLessThan(Date().timeIntervalSince(started), 5)
    }

    func testChildIsStoppedAtTheDeadline() {
        let watchdog = ProcessWatchdog(parentPID: getpid(), deadline: Date().addingTimeInterval(0.5), pollInterval: 0.1, gracePeriod: 1)
        let started = Date()
        _ = watchdog.run(executable: "/bin/sleep", arguments: ["30"], forwardTermination: false)
        XCTAssertLessThan(Date().timeIntervalSince(started), 5)
    }

    func testChildExitStatusIsPassedThrough() {
        let watchdog = ProcessWatchdog(parentPID: getpid(), deadline: nil, pollInterval: 0.1)
        XCTAssertEqual(watchdog.run(executable: "/usr/bin/false", arguments: [], forwardTermination: false), 1)
    }
}
