@testable import KTStackCore
import XCTest
@testable import KTLogsPlugin

final class LogTailLifecycleTests: XCTestCase {
    private var dir: URL!

    override func setUpWithError() throws {
        dir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("kt-tail-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: dir)
    }

    private func openDescriptorCount() -> Int {
        (try? FileManager.default.contentsOfDirectory(atPath: "/dev/fd").count) ?? 0
    }

    func testStoppedAndDroppedReadersCloseTheirFile() async throws {
        let log = dir.appendingPathComponent("a.log")
        try "one\ntwo\n".write(to: log, atomically: true, encoding: .utf8)
        let baseline = openDescriptorCount()
        for _ in 0..<20 {
            var reader: LogTailReader? = LogTailReader(url: log)
            reader?.start()
            try await Task.sleep(for: .milliseconds(20))
            reader?.stop()
            reader = nil
        }
        try await Task.sleep(for: .milliseconds(300))
        XCTAssertLessThanOrEqual(openDescriptorCount(), baseline + 2)
    }

    @MainActor
    func testBatchesFromAPreviousSourceAreDropped() async throws {
        let controller = LogTailController(flushDelay: .milliseconds(10))
        controller.select(LogSource(id: "a", displayName: "a", kind: .service, url: dir.appendingPathComponent("missing-a.log")))
        let stale = controller.generation
        controller.select(LogSource(id: "b", displayName: "b", kind: .service, url: dir.appendingPathComponent("missing-b.log")))
        controller.receive(["from a"], generation: stale)
        controller.receive(["from b"], generation: controller.generation)
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(controller.lines.map(\.text), ["from b"])
        controller.select(nil)
    }

    @MainActor
    func testBatchesAreCoalescedAndFilteredIncrementally() async throws {
        let controller = LogTailController(capacity: 3, flushDelay: .milliseconds(50))
        controller.select(LogSource(id: "a", displayName: "a", kind: .service, url: dir.appendingPathComponent("missing.log")))
        controller.filter = "keep"
        let token = controller.generation
        controller.receive(["keep 1", "drop"], generation: token)
        controller.receive(["keep 2"], generation: token)
        XCTAssertTrue(controller.lines.isEmpty)
        try await Task.sleep(for: .milliseconds(200))
        XCTAssertEqual(controller.lines.map(\.text), ["keep 1", "keep 2"])

        controller.receive(["keep 3", "keep 4"], generation: token)
        try await Task.sleep(for: .milliseconds(200))
        XCTAssertEqual(controller.lines.map(\.text), ["keep 2", "keep 3", "keep 4"])
        controller.filter = ""
        XCTAssertEqual(controller.lines.map(\.text), ["keep 2", "keep 3", "keep 4"])
        controller.select(nil)
    }

    func testIncrementalAppendReportsOnlyRetainedLines() {
        let store = LogLineStore(capacity: 2)
        let first = store.appendIncremental(["a"])
        XCTAssertEqual(first.added.map(\.text), ["a"])
        let second = store.appendIncremental(["b", "c", "d"])
        XCTAssertEqual(second.added.map(\.text), ["c", "d"])
        XCTAssertEqual(second.firstRetainedID, 2)
    }
}
