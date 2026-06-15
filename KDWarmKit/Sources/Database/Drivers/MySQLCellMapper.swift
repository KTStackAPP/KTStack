import Foundation
import MySQLNIO
import NIOCore

/// Maps MySQL text-protocol values into the typed `Cell`. The text protocol returns every value as
/// its UTF-8 text bytes regardless of column type, so the column's declared `DataType` (and charset)
/// decides which `Cell` case to build — not the bytes themselves.
///
/// The classification core takes raw type/charset codes (not `ColumnDefinition41`, whose initializer
/// is internal to MySQLNIO) so the rules are unit-testable from a test target without a live server;
/// a thin `ColumnDefinition41` overload bridges the driver.
enum MySQLCellMapper {
    /// MySQL `DataType` codes that carry string/blob payloads — the only types where the `binary`
    /// charset distinguishes raw bytes from character text.
    private static let stringOrBlobTypes: Set<UInt8> = [
        MySQLProtocol.DataType.tinyBlob.rawValue,
        MySQLProtocol.DataType.mediumBlob.rawValue,
        MySQLProtocol.DataType.longBlob.rawValue,
        MySQLProtocol.DataType.blob.rawValue,
        MySQLProtocol.DataType.varString.rawValue,
        MySQLProtocol.DataType.string.rawValue,
        MySQLProtocol.DataType.varchar.rawValue,
    ]
    private static let integerTypes: Set<UInt8> = [
        MySQLProtocol.DataType.tiny.rawValue,
        MySQLProtocol.DataType.short.rawValue,
        MySQLProtocol.DataType.long.rawValue,
        MySQLProtocol.DataType.int24.rawValue,
        MySQLProtocol.DataType.longlong.rawValue,
        MySQLProtocol.DataType.year.rawValue,
    ]
    /// Only binary floating types map to `.double`. DECIMAL/NEWDECIMAL are exact fixed-point — routing
    /// them through `Double` would silently truncate (e.g. a money column), so they stay `.text` to
    /// preserve the server's exact digits.
    private static let floatTypes: Set<UInt8> = [
        MySQLProtocol.DataType.float.rawValue,
        MySQLProtocol.DataType.double.rawValue,
    ]
    /// MySQL's `binary` charset id — a string/blob type carrying this is raw bytes, not character text.
    static let binaryCharset = MySQLProtocol.CharacterSet.binary.rawValue

    /// Whether a column is a binary string (BLOB/BINARY) rather than character text: a string/blob
    /// type tagged with the `binary` charset. Those become `.blob` so the grid shows a byte summary
    /// instead of mangling raw bytes through UTF-8.
    static func isBinary(typeRaw: UInt8, charsetRaw: UInt8) -> Bool {
        stringOrBlobTypes.contains(typeRaw) && charsetRaw == binaryCharset
    }

    /// Classify a single text-protocol value from raw type/charset codes. A `nil` buffer is SQL NULL.
    /// Integer and binary-float types parse into `.int`/`.double`; a parse failure (e.g. a value past
    /// `Int64`'s range) falls back to `.text` so the value is never dropped. DECIMAL stays `.text` to
    /// keep its exact digits. Binary columns become `.blob`; everything else is `.text`.
    static func cell(typeRaw: UInt8, charsetRaw: UInt8, value: ByteBuffer?) -> Cell {
        guard var buffer = value else { return .null }

        if isBinary(typeRaw: typeRaw, charsetRaw: charsetRaw) {
            return .blob(Data(buffer.readBytes(length: buffer.readableBytes) ?? []))
        }
        guard let text = buffer.readString(length: buffer.readableBytes) else { return .null }

        if integerTypes.contains(typeRaw) { return Int64(text).map(Cell.int) ?? .text(text) }
        if floatTypes.contains(typeRaw)   { return Double(text).map(Cell.double) ?? .text(text) }
        return .text(text)
    }

    // MARK: - ColumnDefinition41 bridge (driver-side)

    static func cell(for column: MySQLProtocol.ColumnDefinition41, value: ByteBuffer?) -> Cell {
        cell(typeRaw: column.columnType.rawValue, charsetRaw: column.characterSet.rawValue, value: value)
    }

    /// Column metadata for the result header: the engine's column name + its declared type name.
    static func columnMeta(_ column: MySQLProtocol.ColumnDefinition41) -> ColumnMeta {
        ColumnMeta(name: column.name, typeName: column.columnType.description)
    }
}
