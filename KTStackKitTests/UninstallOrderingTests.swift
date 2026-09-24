import XCTest
@testable import KTStackKit

@MainActor
final class UninstallOrderingTests: XCTestCase {
    private final class Recorder: @unchecked Sendable {
        private let lock = NSLock()
        private var events: [String] = []

        func add(_ event: String) {
            lock.lock(); events.append(event); lock.unlock()
        }

        var all: [String] {
            lock.lock(); defer { lock.unlock() }; return events
        }
    }

    private struct Boom: LocalizedError {
        var errorDescription: String? { "boom" }
    }

    private func steps(_ recorder: Recorder, dnsFails: Bool = false, removeFails: Bool = false) -> UninstallSteps {
        UninstallSteps(
            quiesce: { recorder.add("quiesce") },
            disableDNS: {
                try await Task.sleep(nanoseconds: 50_000_000)
                recorder.add("dns")
                if dnsFails { throw Boom() }
            },
            disableShell: { recorder.add("shell") },
            untrustCA: { recorder.add("ca") },
            bootoutAll: { recorder.add("bootout") },
            removeDataRoot: {
                recorder.add("remove")
                if removeFails { throw Boom() }
                return URL(fileURLWithPath: "/tmp/Trash/KTStack")
            },
            unregisterHelper: { recorder.add("unregister") },
            resolverLeft: { nil }
        )
    }

    func testStepsRunInOrderWithDNSAwaitedAndHelperUnregisteredLast() async {
        let recorder = Recorder()
        let service = UninstallService(steps: steps(recorder))
        var finished: UninstallService.State?
        service.onFinished = { finished = $0 }

        await service.run()

        XCTAssertEqual(recorder.all, ["quiesce", "dns", "shell", "ca", "bootout", "remove", "unregister"])
        XCTAssertEqual(service.state, .done)
        XCTAssertEqual(finished, .done)
        XCTAssertTrue(service.log.contains { $0.contains("Trash") })
    }

    func testDNSFailureStillCompletesRemainingSteps() async {
        let recorder = Recorder()
        let service = UninstallService(steps: steps(recorder, dnsFails: true))

        await service.run()

        XCTAssertEqual(recorder.all.last, "unregister")
        XCTAssertTrue(service.log.contains { $0.contains("DNS cleanup warning") })
    }

    func testDataRemovalFailureReportsFailedAndDoesNotQuit() async {
        let recorder = Recorder()
        let service = UninstallService(steps: steps(recorder, removeFails: true))
        var finished: UninstallService.State?
        service.onFinished = { finished = $0 }

        await service.run()

        XCTAssertEqual(service.state, .failed("boom"))
        XCTAssertEqual(finished, .failed("boom"))
        XCTAssertEqual(recorder.all.last, "unregister")
    }

    func testResolverLeftBehindIsReportedAsFailure() async {
        let recorder = Recorder()
        var withResolver = steps(recorder)
        withResolver.resolverLeft = { "/etc/resolver/test" }
        let service = UninstallService(steps: withResolver)

        await service.run()

        XCTAssertEqual(service.state, .failed("DNS resolver not removed"))
    }

    func testMoveToTrashSkipsMissingRoot() throws {
        let missing = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        XCTAssertNil(try UninstallSteps.moveToTrash(missing))
    }
}
