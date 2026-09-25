import Foundation
import MongoKitten

enum MongoTypePreserver {
    static func element(_ edited: Any, keepingTypeOf original: Primitive) throws -> MongoRawBSON.Element {
        guard let number = edited as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID() else {
            return try MongoJSONMapper.element(from: edited)
        }
        let isInteger = !CFNumberIsFloatType(number) || number.doubleValue.rounded() == number.doubleValue
        switch original {
        case is Decimal128:
            guard let decimal = MongoDecimal128(string: number.stringValue) else {
                return try MongoJSONMapper.element(from: edited)
            }
            return .decimal(decimal)
        case is Int32 where isInteger && Int32(exactly: number.doubleValue) != nil:
            return .value(Int32(number.int64Value))
        case is Double:
            return .value(number.doubleValue)
        case is Int where isInteger:
            return .value(Int(number.int64Value))
        default:
            return try MongoJSONMapper.element(from: edited)
        }
    }
}
