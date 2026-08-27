import Foundation
import KTPlatformContracts
import KTStackCore

@MainActor
final class SiteSettingsModel: ObservableObject {
    struct EnvRow: Identifiable {
        let id = UUID()
        var key: String
        var value: String
    }

    let siteID: UUID
    let domain: String
    let kind: SiteKind
    let secure: Bool

    @Published var aliases: [String]
    @Published var aliasDraft = ""
    @Published var aliasError: String?

    @Published var envRows: [EnvRow]
    @Published var envError: String?
    @Published var envSaved = false

    @Published var directives: String
    @Published var directivesError: String?
    @Published var directivesNote: String?
    @Published var isSavingDirectives = false

    private let validateAliasesFn: ([String]) throws -> Void
    private let setAliasesFn: ([String]) throws -> Void
    private let setEnvVarsFn: ([String: String]) throws -> Void
    private let saveDirectivesFn: (String) async throws -> Void

    var showsEnv: Bool { kind == .php || kind == .node }

    init(
        site: SiteSummary,
        validateAliases: @escaping ([String]) throws -> Void,
        setAliases: @escaping ([String]) throws -> Void,
        setEnvVars: @escaping ([String: String]) throws -> Void,
        saveDirectives: @escaping (String) async throws -> Void
    ) {
        siteID = site.id
        domain = site.domain
        kind = site.kind
        secure = site.secure
        aliases = site.aliases
        envRows = SiteEnvVars.sorted(site.envVars).map { EnvRow(key: $0.key, value: $0.value) }
        directives = site.frontDirectives ?? ""
        validateAliasesFn = validateAliases
        setAliasesFn = setAliases
        setEnvVarsFn = setEnvVars
        saveDirectivesFn = saveDirectives
    }

    func addAlias() {
        let candidate = aliasDraft.trimmingCharacters(in: .whitespaces).lowercased()
        guard !candidate.isEmpty else { return }
        let next = aliases + [candidate]
        do {
            try validateAliasesFn(next)
            try setAliasesFn(next)
            aliases = next
            aliasDraft = ""
            aliasError = nil
        } catch {
            aliasError = error.localizedDescription
        }
    }

    func removeAlias(_ alias: String) {
        let next = aliases.filter { $0 != alias }
        do {
            try setAliasesFn(next)
            aliases = next
            aliasError = nil
        } catch {
            aliasError = error.localizedDescription
        }
    }

    func addEnvRow() { envRows.append(EnvRow(key: "", value: "")) }

    func removeEnvRow(_ id: UUID) {
        envRows.removeAll { $0.id == id }
        envSaved = false
    }

    func saveEnv() {
        envSaved = false
        var dict: [String: String] = [:]
        for row in envRows {
            let key = row.key.trimmingCharacters(in: .whitespaces)
            guard !key.isEmpty else { continue }
            dict[key] = row.value
        }
        if let err = SiteEnvVars.validate(dict) {
            envError = Self.message(for: err)
            return
        }
        do {
            try setEnvVarsFn(dict)
            envError = nil
            envSaved = true
        } catch {
            envError = error.localizedDescription
        }
    }

    func saveDirectives() async {
        isSavingDirectives = true
        directivesError = nil
        directivesNote = nil
        defer { isSavingDirectives = false }
        do {
            try await saveDirectivesFn(directives)
            directivesNote = "Saved."
        } catch let error as NginxIncludeSaveError {
            switch error {
            case let .rejected(stderr):
                directivesError = "nginx rejected the directives; previous config kept:\n\(stderr)"
            case .couldNotValidate:
                directivesNote = "Saved. nginx is not running, so it was not validated; it applies on next start."
            case let .reloadFailedReverted(message):
                directivesError = "Reload failed, previous directives restored: \(message)"
            }
        } catch {
            directivesError = error.localizedDescription
        }
    }

    private static func message(for error: SiteEnvVarError) -> String {
        switch error {
        case let .invalidKey(key):
            "“\(key)” is not a valid name. Use letters, digits and underscore, and don't start with a digit."
        case let .reservedKey(key):
            "“\(key)” is reserved by KTStack and can't be overridden."
        case let .invalidValue(key):
            "The value for “\(key)” contains a newline or null character."
        }
    }
}
