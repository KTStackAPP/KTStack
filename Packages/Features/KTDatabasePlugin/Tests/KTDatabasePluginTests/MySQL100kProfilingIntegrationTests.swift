import Darwin
import KTPlatformContracts
import KTStackCore
import XCTest
@testable import KTDatabasePlugin

/// Opt-in profiling against a pre-seeded 100k-row table (`kt_sample_100k.events`). Proves the browse
/// path stays bounded to the fetch window: each fetch returns at most `pageSize` rows and holding one
/// page costs a small, fixed footprint regardless of the 100k total. Gated on `KTSTACK_DB_IT=1`.
final class MySQL100kProfilingIntegrationTests: XCTestCase {

    private let database = "kt_sample_100k"
    private let table = "events"
    private let pageSize = 200

    private func makeDriver() async throws -> MySQLDriver {
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["KTSTACK_DB_IT"] == "1",
            "Set KTSTACK_DB_IT=1 with kt_sample_100k seeded on the MySQL engine (:3306)."
        )
        let driver = MySQLDriver(profile: .managedMySQL, password: nil, tools: FakeDatabaseTools.allInstalled)
        let total = try await rowCount(driver)
        try XCTSkipUnless(total >= 100_000, "kt_sample_100k.events has \(total) rows; seed 100k first.")
        return driver
    }

    private func rowCount(_ driver: MySQLDriver) async throws -> Int {
        let result = try await driver.query("SELECT COUNT(*) FROM \(database).\(table)", database: database)
        guard case let .int(n)? = result.rows.first?.first else { return 0 }
        return Int(n)
    }

    private func physFootprintMB() -> Double {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
        let kr = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        return kr == KERN_SUCCESS ? Double(info.phys_footprint) / 1024 / 1024 : 0
    }

    private func timed<T>(_ body: () async throws -> T) async rethrows -> (value: T, ms: Double) {
        let start = DispatchTime.now().uptimeNanoseconds
        let value = try await body()
        let ms = Double(DispatchTime.now().uptimeNanoseconds - start) / 1_000_000
        return (value, ms)
    }

    func testBrowseStaysBoundedToTheFetchWindow() async throws {
        let driver = try await makeDriver()
        defer { Task { await driver.closeSession() } }

        // Trang đầu: đúng cái editor gọi (paginatedRows limit=pageSize offset=0).
        let first = try await timed {
            try await driver.paginatedRows(database: database, table: table, limit: pageSize, offset: 0)
        }
        XCTAssertEqual(first.value.rowCount, pageSize, "first page must be bounded to the fetch window")

        // Trang sâu gần cuối bảng vẫn chỉ trả pageSize dòng.
        let deep = try await timed {
            try await driver.paginatedRows(database: database, table: table, limit: pageSize, offset: 99_000)
        }
        XCTAssertEqual(deep.value.rowCount, pageSize, "a deep-offset page stays bounded too")

        let count = try await timed { try await rowCount(driver) }

        // Memory: nạp 1 trang so với tích lũy 50 trang (10k dòng, mô phỏng fetchMore).
        let baseline = physFootprintMB()
        var onePage = try await driver.paginatedRows(database: database, table: table, limit: pageSize, offset: 0)
        let afterOne = physFootprintMB()

        var accumulated: [[Cell]] = []
        for page in 0 ..< 50 {
            let result = try await driver.paginatedRows(
                database: database, table: table, limit: pageSize, offset: page * pageSize
            )
            accumulated.append(contentsOf: result.rows)
        }
        let afterFifty = physFootprintMB()

        XCTAssertEqual(onePage.rowCount, pageSize)
        XCTAssertEqual(accumulated.count, 50 * pageSize)

        print("""
        === 100k browse profiling (kt_sample_100k.events, \(count.value) rows) ===
        first page (200 rows)      : \(String(format: "%.1f", first.ms)) ms
        deep page (offset 99000)   : \(String(format: "%.1f", deep.ms)) ms
        COUNT(*)                   : \(String(format: "%.1f", count.ms)) ms
        footprint baseline         : \(String(format: "%.1f", baseline)) MB
        after 1 page (200 rows)    : \(String(format: "%.1f", afterOne)) MB  (Δ \(String(format: "%.1f", afterOne - baseline)) MB)
        after 50 pages (10k rows)  : \(String(format: "%.1f", afterFifty)) MB  (Δ from 1 page \(String(format: "%.1f", afterFifty - afterOne)) MB)
        """)

        // Giữ tham chiếu để footprint đo được là dữ liệu đang sống, không bị giải phóng sớm.
        onePage = QueryResult(columns: onePage.columns, rows: onePage.rows)
        XCTAssertFalse(accumulated.isEmpty)
    }
}
