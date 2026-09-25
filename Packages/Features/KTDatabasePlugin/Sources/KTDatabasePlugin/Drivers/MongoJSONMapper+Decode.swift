import Foundation
import MongoKitten
import NIOCore

extension MongoJSONMapper {
    static func document(fromJSON json: String) throws -> Document {
        guard let dictionary = try parse(json) as? [String: Any] else {
            throw DatabaseError.syntax("A document must be a JSON object.")
        }
        return try document(from: dictionary)
    }

    static func element(fromJSON json: String) throws -> MongoRawBSON.Element {
        try element(from: parse(json))
    }

    static func document(from dictionary: [String: Any]) throws -> Document {
        let keys = dictionary.keys.sorted { ($0 == "_id" ? 0 : 1, $0) < ($1 == "_id" ? 0 : 1, $1) }
        let elements = try keys.map { key in (key, try element(from: dictionary[key] ?? NSNull())) }
        return MongoRawBSON.document(elements, isArray: false)
    }

    static func element(from any: Any) throws -> MongoRawBSON.Element {
        switch any {
        case let dictionary as [String: Any]:
            if let wrapped = try wrappedElement(dictionary) { return wrapped }
            return .value(try document(from: dictionary))
        case let array as [Any]:
            let items = try array.enumerated().map { (String($0.offset), try element(from: $0.element)) }
            return .value(MongoRawBSON.document(items, isArray: true))
        case let string as String: return .value(string)
        case is NSNull: return .value(Null())
        case let number as NSNumber: return .value(numberPrimitive(number))
        default: return .value(String(describing: any))
        }
    }

    static func isWrapper(_ dictionary: [String: Any]) -> Bool {
        do { return try wrappedElement(dictionary) != nil } catch { return true }
    }

    static func wrappedElement(_ object: [String: Any]) throws -> MongoRawBSON.Element? {
        try scalarWrapper(object) ?? structuredWrapper(object)
    }

    private static func text(_ object: [String: Any], _ key: String) throws -> String {
        guard let value = object[key] as? String else { throw invalid(key) }
        return value
    }

    private static func scalarWrapper(_ object: [String: Any]) throws -> MongoRawBSON.Element? {
        let keys = Set(object.keys)
        switch true {
        case keys == [Hint.objectId]:
            guard let id = try ObjectId(text(object, Hint.objectId)) else { throw invalid(Hint.objectId) }
            return .value(id)
        case keys == [Hint.date]:
            return .datetime(try dateMilliseconds(object[Hint.date] as Any))
        case keys == [Hint.decimal]:
            guard let decimal = try MongoDecimal128(string: text(object, Hint.decimal)) else { throw invalid(Hint.decimal) }
            return .decimal(decimal)
        case keys == [Hint.long]:
            guard let value = try Int64(text(object, Hint.long)) else { throw invalid(Hint.long) }
            return .value(Int(value))
        case keys == [Hint.int]:
            guard let value = try Int32(text(object, Hint.int)) else { throw invalid(Hint.int) }
            return .value(value)
        case keys == [Hint.double]:
            guard let value = try double(text(object, Hint.double)) else { throw invalid(Hint.double) }
            return .value(value)
        case keys == [Hint.symbol]:
            return .value(try text(object, Hint.symbol))
        default:
            return nil
        }
    }

    private static func structuredWrapper(_ object: [String: Any]) throws -> MongoRawBSON.Element? {
        let keys = Set(object.keys)
        switch true {
        case keys == [Hint.binary], keys == [Hint.binary, "$type"]:
            return .value(try binary(object))
        case keys == [Hint.uuid]:
            guard let bytes = try uuidBytes(text(object, Hint.uuid)) else { throw invalid(Hint.uuid) }
            return .value(Binary(subType: .uuid, buffer: ByteBuffer(bytes: bytes)))
        case keys == [Hint.timestamp]:
            return .value(try timestamp(object[Hint.timestamp]))
        case keys == [Hint.regex]:
            guard let regex = object[Hint.regex] as? [String: Any],
                  let pattern = regex["pattern"] as? String, let options = regex["options"] as? String
            else { throw invalid(Hint.regex) }
            return .value(RegularExpression(pattern: pattern, options: String(options.sorted())))
        case keys == [Hint.code]:
            return .value(JavaScriptCode(try text(object, Hint.code)))
        case keys == [Hint.code, Hint.scope]:
            guard let scope = object[Hint.scope] as? [String: Any] else { throw invalid(Hint.scope) }
            return .value(JavaScriptCodeWithScope(try text(object, Hint.code), scope: try document(from: scope)))
        case keys == [Hint.minKey]:
            return .value(MinKey())
        case keys == [Hint.maxKey]:
            return .value(MaxKey())
        default:
            return nil
        }
    }

    private static func parse(_ json: String) throws -> Any {
        try JSONSerialization.jsonObject(with: Data(json.utf8), options: [.fragmentsAllowed])
    }

    private static func invalid(_ hint: String) -> DatabaseError {
        .syntax("The \(hint) value isn't valid Extended JSON.")
    }

    private static func dateMilliseconds(_ value: Any) throws -> Int64 {
        if let text = value as? String,
           let date = ISO8601DateFormatter.mongo.date(from: text) ?? ISO8601DateFormatter.mongoWholeSeconds.date(from: text)
        {
            return milliseconds(of: date)
        }
        if let wrapped = value as? [String: Any], wrapped.count == 1,
           let text = wrapped[Hint.long] as? String, let millis = Int64(text)
        {
            return millis
        }
        if let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID() { return number.int64Value }
        throw invalid(Hint.date)
    }

    private static func binary(_ object: [String: Any]) throws -> Binary {
        let base64: String?
        let subTypeText: String?
        if let canonical = object[Hint.binary] as? [String: Any], object.count == 1 {
            base64 = canonical["base64"] as? String
            subTypeText = canonical["subType"] as? String
        } else {
            base64 = object[Hint.binary] as? String
            subTypeText = object["$type"] as? String ?? "00"
        }
        guard let base64, let data = Data(base64Encoded: base64),
              let subTypeText, let byte = UInt8(subTypeText, radix: 16)
        else { throw invalid(Hint.binary) }
        return Binary(subType: subType(byte), buffer: ByteBuffer(bytes: Array(data)))
    }

    private static func uuidBytes(_ text: String) -> [UInt8]? {
        let hex = Array(text.replacingOccurrences(of: "-", with: ""))
        guard hex.count == 32 else { return nil }
        let bytes = stride(from: 0, to: 32, by: 2).compactMap { UInt8(String(hex[$0...$0 + 1]), radix: 16) }
        return bytes.count == 16 ? bytes : nil
    }

    private static func timestamp(_ value: Any?) throws -> Timestamp {
        guard let stamp = value as? [String: Any],
              let seconds = (stamp["t"] as? NSNumber)?.int64Value, let increment = (stamp["i"] as? NSNumber)?.int64Value,
              let time = UInt32(exactly: seconds), let ordinal = UInt32(exactly: increment)
        else { throw invalid(Hint.timestamp) }
        return Timestamp(increment: Int32(bitPattern: ordinal), timestamp: Int32(bitPattern: time))
    }

    private static func double(_ text: String) -> Double? {
        switch text {
        case "Infinity": .infinity
        case "-Infinity": -.infinity
        case "NaN": .nan
        default: Double(text)
        }
    }

    static func numberPrimitive(_ number: NSNumber) -> Primitive {
        if CFGetTypeID(number) == CFBooleanGetTypeID() { return number.boolValue }
        if CFNumberIsFloatType(number) { return number.doubleValue }
        return Int(number.int64Value)
    }
}
