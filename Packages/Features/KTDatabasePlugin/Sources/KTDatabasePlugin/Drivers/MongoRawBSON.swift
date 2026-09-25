import Foundation
import MongoKitten

enum MongoRawBSON {
    enum Element {
        case value(Primitive)
        case decimal(MongoDecimal128)
        case datetime(Int64)
    }

    struct Field {
        let key: String
        let type: UInt8
        let value: ArraySlice<UInt8>
    }

    static func fields(of document: Document) -> [Field] {
        let bytes = Array(document.makeData())
        var fields: [Field] = []
        var offset = 4
        while offset < bytes.count, bytes[offset] != 0 {
            let type = bytes[offset]
            guard let keyEnd = bytes[(offset + 1)...].firstIndex(of: 0),
                  let length = valueLength(type, bytes, at: keyEnd + 1),
                  keyEnd + 1 + length <= bytes.count
            else { break }
            let key = String(decoding: bytes[(offset + 1) ..< keyEnd], as: UTF8.self)
            fields.append(Field(key: key, type: type, value: bytes[(keyEnd + 1) ..< (keyEnd + 1 + length)]))
            offset = keyEnd + 1 + length
        }
        return fields
    }

    static func decimals(in document: Document) -> [String: MongoDecimal128] {
        var found: [String: MongoDecimal128] = [:]
        for field in fields(of: document) where field.type == 0x13 {
            let start = field.value.startIndex
            found[field.key] = MongoDecimal128(
                low: littleEndian(field.value[start ..< start + 8]),
                high: littleEndian(field.value[(start + 8) ..< (start + 16)])
            )
        }
        return found
    }

    static func document(_ elements: [(String, Element)], isArray: Bool) -> Document {
        var body: [UInt8] = []
        for (key, element) in elements {
            body += bytes(for: key, element)
        }
        var output = littleEndianBytes(UInt32(body.count + 5))
        output += body
        output.append(0)
        return Document(bytes: output, isArray: isArray)
    }

    private static func bytes(for key: String, _ element: Element) -> [UInt8] {
        let name = Array(key.utf8) + [0]
        switch element {
        case let .decimal(decimal):
            return [0x13] + name + littleEndianBytes(decimal.low) + littleEndianBytes(decimal.high)
        case let .datetime(milliseconds):
            return [0x09] + name + littleEndianBytes(UInt64(bitPattern: milliseconds))
        case let .value(primitive):
            var single = Document()
            single.appendValue(primitive, forKey: "k")
            let raw = Array(single.makeData())
            return [raw[4]] + name + raw[7 ..< (raw.count - 1)]
        }
    }

    private static func valueLength(_ type: UInt8, _ bytes: [UInt8], at offset: Int) -> Int? {
        func int32() -> Int? {
            guard offset + 4 <= bytes.count else { return nil }
            return Int(Int32(bitPattern: UInt32(truncatingIfNeeded: littleEndian(bytes[offset ..< offset + 4]))))
        }
        switch type {
        case 0x01, 0x09, 0x11, 0x12: return 8
        case 0x02, 0x0D, 0x0E: return int32().map { 4 + $0 }
        case 0x03, 0x04, 0x0F: return int32()
        case 0x05: return int32().map { 5 + $0 }
        case 0x06, 0x0A, 0x7F, 0xFF: return 0
        case 0x07: return 12
        case 0x08: return 1
        case 0x0B:
            guard let patternEnd = bytes[offset...].firstIndex(of: 0),
                  let optionsEnd = bytes[(patternEnd + 1)...].firstIndex(of: 0)
            else { return nil }
            return optionsEnd + 1 - offset
        case 0x0C: return int32().map { 16 + $0 }
        case 0x10: return 4
        case 0x13: return 16
        default: return nil
        }
    }

    private static func littleEndian(_ bytes: ArraySlice<UInt8>) -> UInt64 {
        bytes.reversed().reduce(0) { ($0 << 8) | UInt64($1) }
    }

    private static func littleEndianBytes<T: FixedWidthInteger>(_ value: T) -> [UInt8] {
        withUnsafeBytes(of: value.littleEndian, Array.init)
    }
}
