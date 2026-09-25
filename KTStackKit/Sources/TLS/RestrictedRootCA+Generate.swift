import Foundation
import KTStackCore

public extension RestrictedRootCA {
    enum GenerationError: LocalizedError {
        case toolFailed(String)

        public var errorDescription: String? {
            switch self {
            case let .toolFailed(message): "Could not create the local CA: \(message)"
            }
        }
    }

    static let caFileNames = ["rootCA.pem", "rootCA-key.pem", markerName]

    static func generate(caDir: URL, tlds: [String], openssl: String = "/usr/bin/openssl") throws {
        let staged = try stage(caDir: caDir, tlds: tlds, openssl: openssl)
        defer { try? FileManager.default.removeItem(at: staged) }
        try install(staged: staged, caDir: caDir)
    }

    static func stage(caDir: URL, tlds: [String], openssl: String = "/usr/bin/openssl") throws -> URL {
        let fm = FileManager.default
        let staged = caDir.appendingPathComponent(".staging-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: staged, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        do {
            let key = staged.appendingPathComponent("rootCA-key.pem")
            let cert = staged.appendingPathComponent("rootCA.pem")
            let config = staged.appendingPathComponent("ca.cnf")
            let tag = String(UUID().uuidString.prefix(8))
            try opensslConfig(tlds: tlds, tag: tag).write(to: config, atomically: true, encoding: .utf8)
            try run(openssl, ["genpkey", "-algorithm", "RSA", "-pkeyopt", "rsa_keygen_bits:3072", "-out", key.path])
            try fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: key.path)
            let serial = "0x" + UUID().uuidString.replacingOccurrences(of: "-", with: "")
            try run(openssl, [
                "req", "-x509", "-new", "-key", key.path, "-config", config.path,
                "-days", "3650", "-sha256", "-set_serial", serial, "-out", cert.path,
            ])
            let pem = try Data(contentsOf: cert)
            if let rejection = RootCAConstraint.validateKTStackRootCA(pemData: pem) {
                throw GenerationError.toolFailed(rejection.message)
            }
            let marker = Marker(fingerprint: fingerprint(pem: pem) ?? "", tlds: tlds)
            try JSONEncoder().encode(marker).write(to: staged.appendingPathComponent(markerName))
            return staged
        } catch {
            try? fm.removeItem(at: staged)
            throw error
        }
    }

    static func install(staged: URL, caDir: URL) throws {
        let fm = FileManager.default
        try retireExisting(caDir: caDir)
        for name in caFileNames {
            try fm.moveItem(at: staged.appendingPathComponent(name), to: caDir.appendingPathComponent(name))
        }
    }

    static func retireExisting(caDir: URL) throws {
        let fm = FileManager.default
        let present = caFileNames.filter { fm.fileExists(atPath: caDir.appendingPathComponent($0).path) }
        guard !present.isEmpty else { return }
        let stamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "")
        let dest = caDir.appendingPathComponent("retired/\(stamp)-\(UUID().uuidString.prefix(8))", isDirectory: true)
        try fm.createDirectory(at: dest, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        for name in present {
            try fm.moveItem(at: caDir.appendingPathComponent(name), to: dest.appendingPathComponent(name))
        }
    }

    private static func run(_ tool: String, _ args: [String]) throws {
        let res = try ProcessRunner().run(tool, args, timeout: ToolTimeout.keyGeneration)
        guard res.succeeded else {
            let detail = res.stderrText.trimmingCharacters(in: .whitespacesAndNewlines)
            throw GenerationError.toolFailed(detail.isEmpty ? "openssl \(args.first ?? "") failed" : detail)
        }
    }
}
