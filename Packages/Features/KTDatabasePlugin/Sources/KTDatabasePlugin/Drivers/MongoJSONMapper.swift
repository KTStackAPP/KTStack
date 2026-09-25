import Foundation
import MongoKitten

enum MongoJSONMapper {
    enum Hint {
        static let objectId = "$oid"
        static let date = "$date"
        static let decimal = "$numberDecimal"
        static let long = "$numberLong"
        static let int = "$numberInt"
        static let double = "$numberDouble"
        static let binary = "$binary"
        static let uuid = "$uuid"
        static let timestamp = "$timestamp"
        static let regex = "$regularExpression"
        static let code = "$code"
        static let scope = "$scope"
        static let minKey = "$minKey"
        static let maxKey = "$maxKey"
        static let symbol = "$symbol"
    }

    static func encodedJSON(from document: Document, pretty: Bool) throws -> String {
        let object = jsonObject(from: document)
        var options: JSONSerialization.WritingOptions = [.fragmentsAllowed]
        if pretty { options.insert(.prettyPrinted); options.insert(.sortedKeys) }
        let data = try JSONSerialization.data(withJSONObject: object, options: options)
        return String(decoding: data, as: UTF8.self)
    }

    static func identifierJSON(in document: Document) -> String? {
        guard let identifier = document["_id"] else { return nil }
        let object = jsonValue(from: identifier, decimal: MongoRawBSON.decimals(in: document)["_id"])
        guard let data = try? JSONSerialization.data(withJSONObject: object, options: [.fragmentsAllowed, .sortedKeys])
        else { return nil }
        return String(decoding: data, as: UTF8.self)
    }

    static func displayID(in document: Document) -> String {
        switch document["_id"] {
        case let id as ObjectId: id.hexString
        case let s as String: s
        case is Decimal128: MongoRawBSON.decimals(in: document)["_id"]?.description ?? "—"
        case let value?: String(describing: value)
        case nil: "—"
        }
    }

    static func jsonObject(from document: Document) -> Any {
        let decimals = MongoRawBSON.decimals(in: document)
        var items: [Any] = []
        var result: [String: Any] = [:]
        for (key, value) in document {
            let json = jsonValue(from: value, decimal: decimals[key])
            if document.isArray { items.append(json) } else { result[key] = json }
        }
        return document.isArray ? items : result
    }

    static func jsonValue(from primitive: Primitive, decimal: MongoDecimal128? = nil) -> Any {
        switch primitive {
        case let nested as Document: jsonObject(from: nested)
        case let id as ObjectId: [Hint.objectId: id.hexString]
        case let date as Date: dateJSON(date)
        case is Decimal128: [Hint.decimal: decimal?.description ?? "NaN"]
        case let binary as Binary: binaryJSON(binary)
        case let stamp as Timestamp:
            [Hint.timestamp: ["t": UInt32(bitPattern: stamp.timestamp), "i": UInt32(bitPattern: stamp.increment)]]
        case let regex as RegularExpression: [Hint.regex: ["pattern": regex.pattern, "options": regex.options]]
        case let code as JavaScriptCode: [Hint.code: code.code]
        case let code as JavaScriptCodeWithScope: [Hint.code: code.code, Hint.scope: jsonObject(from: code.scope)]
        case is MinKey: [Hint.minKey: 1]
        case is MaxKey: [Hint.maxKey: 1]
        case is Null: NSNull()
        case let bool as Bool: bool
        case let int as Int: int
        case let int as Int32: Int(int)
        case let int as Int64: Int(int)
        case let double as Double: double.isFinite ? double as Any : [Hint.double: nonFiniteText(double)]
        case let string as String: string
        default: String(describing: primitive)
        }
    }

    static func milliseconds(of date: Date) -> Int64 {
        Int64((date.timeIntervalSince1970 * 1000).rounded())
    }

    private static func dateJSON(_ date: Date) -> Any {
        let millis = milliseconds(of: date)
        guard (0...253_402_300_799_999).contains(millis) else {
            return [Hint.date: [Hint.long: String(millis)]]
        }
        let whole = Date(timeIntervalSince1970: Double(millis / 1000))
        let seconds = ISO8601DateFormatter.mongoWholeSeconds.string(from: whole).dropLast()
        return [Hint.date: String(seconds) + String(format: ".%03ldZ", Int(millis % 1000))]
    }

    private static func binaryJSON(_ binary: Binary) -> Any {
        [Hint.binary: ["base64": binary.data.base64EncodedString(), "subType": String(format: "%02x", subTypeByte(binary.subType))]]
    }

    static func subTypeByte(_ subType: Binary.SubType) -> UInt8 {
        switch subType {
        case .generic: 0x00
        case .function: 0x01
        case .uuid: 0x04
        case .md5: 0x05
        case let .userDefined(byte): byte
        }
    }

    static func subType(_ byte: UInt8) -> Binary.SubType {
        switch byte {
        case 0x00: .generic
        case 0x01: .function
        case 0x04: .uuid
        case 0x05: .md5
        default: .userDefined(byte)
        }
    }

    private static func nonFiniteText(_ double: Double) -> String {
        double.isNaN ? "NaN" : (double > 0 ? "Infinity" : "-Infinity")
    }
}

extension ISO8601DateFormatter {
    static let mongo: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    static let mongoWholeSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
}
