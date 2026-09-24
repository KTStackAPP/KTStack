import Foundation
import MongoKitten

struct MongoUpdatePlan {
    var set = Document()
    var unset: [String] = []

    var updateDocument: Document? {
        var update = Document()
        if !set.keys.isEmpty { update["$set"] = set }
        if !unset.isEmpty {
            var removed = Document()
            for path in unset { removed[path] = "" }
            update["$unset"] = removed
        }
        return update.keys.isEmpty ? nil : update
    }
}

enum MongoDocumentDiff {
    static func plan(original: Document, editedJSON: String) throws -> MongoUpdatePlan {
        let parsed = try JSONSerialization.jsonObject(with: Data(editedJSON.utf8), options: [.fragmentsAllowed])
        guard let edited = parsed as? [String: Any] else {
            throw DatabaseError.syntax("A document must be a JSON object.")
        }
        var plan = MongoUpdatePlan()
        try diff(original: original, edited: edited, prefix: "", into: &plan)
        return plan
    }

    private static func diff(
        original: Document,
        edited: [String: Any],
        prefix: String,
        into plan: inout MongoUpdatePlan
    ) throws {
        for key in original.keys where edited[key] == nil && !(prefix.isEmpty && key == "_id") {
            let fieldPath = path(prefix, key)
            if let old = original[key], let lossy = firstLossy(in: old) { throw refusal(fieldPath, lossy) }
            plan.unset.append(fieldPath)
        }
        for key in edited.keys.sorted() where !(prefix.isEmpty && key == "_id") {
            guard let newValue = edited[key] else { continue }
            let fieldPath = path(prefix, key)
            guard let old = original[key] else {
                plan.set[fieldPath] = MongoJSONMapper.primitive(from: newValue)
                continue
            }
            if sameJSON(MongoJSONMapper.jsonValue(from: old), newValue) { continue }
            if let oldDocument = old as? Document, !oldDocument.isArray,
               let newDictionary = newValue as? [String: Any],
               MongoJSONMapper.hintedPrimitive(newDictionary) == nil
            {
                try diff(original: oldDocument, edited: newDictionary, prefix: fieldPath, into: &plan)
                continue
            }
            if let lossy = firstLossy(in: old) { throw refusal(fieldPath, lossy) }
            plan.set[fieldPath] = MongoTypePreserver.value(newValue, keepingTypeOf: old)
        }
    }

    private static func firstLossy(in value: Primitive) -> String? {
        if let document = value as? Document { return MongoLossyFieldScanner.scan(document).first?.typeName }
        return MongoLossyFieldScanner.lossyTypeName(value)
    }

    private static func refusal(_ path: String, _ typeName: String) -> DatabaseError {
        .syntax("“\(path)” holds a \(typeName) value that the editor can't write back unchanged. "
            + "Leave it as is, or edit it with mongosh or MongoDB Compass.")
    }

    private static func path(_ prefix: String, _ key: String) -> String {
        prefix.isEmpty ? key : "\(prefix).\(key)"
    }

    static func sameJSON(_ lhs: Any, _ rhs: Any) -> Bool {
        let options: JSONSerialization.WritingOptions = [.fragmentsAllowed, .sortedKeys]
        guard let left = try? JSONSerialization.data(withJSONObject: lhs, options: options),
              let right = try? JSONSerialization.data(withJSONObject: rhs, options: options)
        else { return false }
        return left == right
    }
}
