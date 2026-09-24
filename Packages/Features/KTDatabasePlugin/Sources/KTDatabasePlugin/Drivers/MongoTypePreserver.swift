import Foundation
import MongoKitten

enum MongoTypePreserver {
    static func value(_ edited: Any, keepingTypeOf original: Primitive) -> Primitive {
        guard let number = edited as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID() else {
            return MongoJSONMapper.primitive(from: edited)
        }
        let isInteger = !CFNumberIsFloatType(number) || number.doubleValue.rounded() == number.doubleValue
        switch original {
        case is Int32 where isInteger && Int32(exactly: number.doubleValue) != nil:
            return Int32(number.int64Value)
        case is Double:
            return number.doubleValue
        case is Int where isInteger:
            return Int(number.int64Value)
        default:
            return MongoJSONMapper.primitive(from: edited)
        }
    }
}
