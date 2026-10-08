import NIOCore
import PostgresNIO
import XCTest
@testable import KTDatabasePlugin

/// Engine-free coverage of binary-format Postgres values rendered as psql text. Bytes are the
/// big-endian wire layouts PostgresNIO receives from the extended query protocol.
final class PostgresCellMapperTests: XCTestCase {
    private func cell(_ type: PostgresDataType, format: PostgresFormat = .binary, _ write: (inout ByteBuffer) -> Void) -> Cell {
        var buffer = ByteBuffer()
        write(&buffer)
        return PostgresCellMapper.cell(
            PostgresCell(bytes: buffer, dataType: type, format: format, columnName: "c", columnIndex: 0)
        )
    }

    private func timestamp(_ micros: Int64, _ type: PostgresDataType = .timestamp) -> Cell {
        cell(type) { $0.writeInteger(micros) }
    }

    private func numeric(weight: Int16, sign: UInt16 = 0, scale: Int16, _ groups: [Int16]) -> Cell {
        cell(.numeric) { buffer in
            buffer.writeInteger(Int16(groups.count))
            buffer.writeInteger(weight)
            buffer.writeInteger(sign)
            buffer.writeInteger(scale)
            groups.forEach { buffer.writeInteger($0) }
        }
    }

    func testTimestampEpochAndFractionTrimming() {
        XCTAssertEqual(timestamp(0), .text("2000-01-01 00:00:00"))
        XCTAssertEqual(timestamp(768_294_489_500_000), .text("2024-05-06 07:08:09.5"))
        XCTAssertEqual(timestamp(-1), .text("1999-12-31 23:59:59.999999"))
    }

    func testTimestamptzRendersInUTC() {
        XCTAssertEqual(timestamp(768_294_489_500_000, .timestamptz), .text("2024-05-06 07:08:09.5+00"))
    }

    func testTimestampInfinitySentinels() {
        XCTAssertEqual(timestamp(.max), .text("infinity"))
        XCTAssertEqual(timestamp(.min, .timestamptz), .text("-infinity"))
    }

    func testDateIncludingBCEra() {
        XCTAssertEqual(cell(.date) { $0.writeInteger(Int32(0)) }, .text("2000-01-01"))
        XCTAssertEqual(cell(.date) { $0.writeInteger(Int32(-730_120)) }, .text("0001-12-31 BC"))
        XCTAssertEqual(cell(.date) { $0.writeInteger(Int32.max) }, .text("infinity"))
    }

    func testTimeAndTimetz() {
        XCTAssertEqual(cell(.time) { $0.writeInteger(Int64(49_530_250_000)) }, .text("13:45:30.25"))
        let tenAM = Int64(10 * 3600) * 1_000_000
        XCTAssertEqual(cell(.timetz) { $0.writeInteger(tenAM); $0.writeInteger(Int32(-25200)) }, .text("10:00:00+07"))
        XCTAssertEqual(cell(.timetz) { $0.writeInteger(tenAM); $0.writeInteger(Int32(19800)) }, .text("10:00:00-05:30"))
    }

    func testIntervalMatchesPostgresStyle() {
        func interval(months: Int32, days: Int32, micros: Int64) -> Cell {
            cell(.interval) { $0.writeInteger(micros); $0.writeInteger(days); $0.writeInteger(months) }
        }
        XCTAssertEqual(interval(months: 14, days: 3, micros: 14_706_500_000), .text("1 year 2 mons 3 days 04:05:06.5"))
        XCTAssertEqual(interval(months: 0, days: 0, micros: 0), .text("00:00:00"))
        XCTAssertEqual(interval(months: -12, days: 0, micros: 3_600_000_000), .text("-1 years +01:00:00"))
    }

    func testNumericKeepsScaleAndSign() {
        XCTAssertEqual(numeric(weight: 0, scale: 2, [12, 5000]), .text("12.50"))
        XCTAssertEqual(numeric(weight: -2, sign: 0x4000, scale: 5, [1000]), .text("-0.00001"))
        XCTAssertEqual(numeric(weight: 2, scale: 0, [1, 2345, 6789]), .text("123456789"))
        XCTAssertEqual(numeric(weight: 1, scale: 0, [1]), .text("10000"))
        XCTAssertEqual(numeric(weight: 0, sign: 0xC000, scale: 0, []), .text("NaN"))
    }

    // Captured from PostgreSQL via `*_send(value)` and `value::text` with TimeZone = UTC.
    func testServerCapturedWireVectors() {
        let vectors: [(PostgresDataType, String, String)] = [
            (.timestamp, "0002bac280212960", "2024-05-06 07:08:09.5"),
            (.timestamp, "ff1af9e8fb46d000", "0044-03-15 12:00:00 BC"),
            (.timestamptz, "00030055ee39e400", "2026-10-08 16:59:59.123456+00"),
            (.date, "ffffd533", "1970-01-01"),
            (.date, "fff4dbf8", "0001-12-31 BC"),
            (.time, "000000141dd76000", "24:00:00"),
            (.time, "0000000000000001", "00:00:00.000001"),
            (.timetz, "0000000861c46800ffffb2a8", "10:00:00+05:30"),
            (.timetz, "0000000861c4680000007080", "10:00:00-08"),
            (.interval, "00000000d693a400fffffffdfffffff6", "-10 mons -3 days +01:00:00"),
            (.interval, "0000001e2cc310000000000000000000", "36:00:00"),
            (.interval, "fffffffffff85ee00000000000000000", "-00:00:00.5"),
            (.numeric, "0002000000000002000c1388", "12.50"),
            (.numeric, "0001fffe4000000503e8", "-0.00001"),
            (.numeric, "00040002000000040001000000000001", "100000000.0001"),
            (.numeric, "0000000000000002", "0.00"),
            (.numeric, "000200004000000104d21388", "-1234.5"),
        ]
        for (type, hex, expected) in vectors {
            let bytes = stride(from: 0, to: hex.count, by: 2).map { offset -> UInt8 in
                let start = hex.index(hex.startIndex, offsetBy: offset)
                return UInt8(hex[start ... hex.index(after: start)], radix: 16)!
            }
            XCTAssertEqual(cell(type) { $0.writeBytes(bytes) }, .text(expected), "\(type) \(hex)")
        }
    }

    func testTextFormatPassesThrough() {
        let literal = "2024-05-06 07:08:09.5"
        XCTAssertEqual(cell(.timestamp, format: .text) { $0.writeString(literal) }, .text(literal))
    }
}
