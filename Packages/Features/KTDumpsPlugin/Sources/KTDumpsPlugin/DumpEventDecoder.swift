import Foundation

public enum DumpEventDecoder {
    public static func decode(line: Data) throws -> DumpEvent {
        guard let json = try? JSONSerialization.jsonObject(with: line) as? [String: Any] else {
            throw DecoderError.invalidJSON
        }
        let timestamp = (json["timestamp"] as? Double).map { Date(timeIntervalSince1970: $0) } ?? Date()
        let file = json["file"] as? String ?? ""
        let line = json["line"] as? Int ?? 0
        let valueJSON = json["value"] as? [String: Any] ?? [:]
        let root = buildNode(from: valueJSON)
        return DumpEvent(timestamp: timestamp, file: file, line: line, root: root)
    }

    private static func buildNode(from json: [String: Any]) -> DumpNode {
        switch json["type"] as? String {
        case "null":
            return .scalar("null")
        case "bool":
            return .scalar((json["value"] as? Bool) == true ? "true" : "false")
        case "int":
            let v = json["value"] as? Int ?? 0
            return .scalar(String(v))
        case "float":
            let v = json["value"] as? Double ?? 0
            return .scalar(String(v))
        case "string":
            let v = json["value"] as? String ?? ""
            let len = json["length"] as? Int ?? v.count
            return .scalar("\"\(v)\" (\(len))")
        case "array":
            let items = json["items"] as? [[String: Any]] ?? []
            let children = items.map { item in
                (key: item["key"] as? String ?? "", value: buildNode(from: item["value"] as? [String: Any] ?? [:]))
            }
            return .array(children)
        case "object":
            let cls = json["class"] as? String ?? "object"
            let props = json["properties"] as? [[String: Any]] ?? []
            let children = props.map { prop in
                (key: prop["key"] as? String ?? "", value: buildNode(from: prop["value"] as? [String: Any] ?? [:]))
            }
            return .object(className: cls, properties: children)
        case "truncated":
            return .scalar("…")
        case "resource":
            return .scalar("resource")
        default:
            return .scalar(json["type"] as? String ?? "unknown")
        }
    }

    public enum DecoderError: Error {
        case invalidJSON
    }
}
