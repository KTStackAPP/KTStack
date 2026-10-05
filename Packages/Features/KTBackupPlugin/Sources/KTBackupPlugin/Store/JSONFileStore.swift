import Foundation

struct JSONFileStore<Value: Codable> {
    let url: URL
    let fallback: Value
    var fileManager: FileManager = .default

    func load() -> Value {
        guard let data = try? Data(contentsOf: url) else { return fallback }
        do {
            return try Self.decoder.decode(Value.self, from: data)
        } catch {
            quarantineCorruptFile()
            return fallback
        }
    }

    func save(_ value: Value) throws {
        try fileManager.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        let data = try Self.encoder.encode(value)
        try data.write(to: url, options: .atomic)
        try? fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    private func quarantineCorruptFile() {
        let stamp = Int(Date().timeIntervalSince1970)
        let target = url.appendingPathExtension("corrupt-\(stamp)")
        try? fileManager.moveItem(at: url, to: target)
    }

    static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
