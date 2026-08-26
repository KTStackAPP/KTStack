import Foundation
import KTPlatformContracts

enum RouteTab: Hashable { case web, api }

enum RequestBodyMode: String, CaseIterable, Hashable {
    case none, json, form

    var label: String {
        switch self {
        case .none: "None"
        case .json: "JSON"
        case .form: "Form"
        }
    }
}

struct EditablePair: Identifiable, Hashable {
    let id = UUID()
    var key: String
    var value: String
    var enabled: Bool = true
}

struct RequestDraft: Hashable {
    var pathParams: [EditablePair] = []
    var query: [EditablePair] = []
    var headers: [EditablePair] = []
    var bodyMode: RequestBodyMode = .none
    var bodyText: String = ""
    var formFields: [EditablePair] = []
}

@MainActor
final class APITesterViewModel: ObservableObject {
    @Published var routes: [APIRoute] = []
    @Published var tab: RouteTab = .web
    @Published var filter: String = ""
    @Published var selected: APIRoute?
    @Published var timeoutSeconds: Double = 30
    @Published var bodyDisplayLimitMB: Int = 2
    @Published var requestDraft = RequestDraft()
    @Published var variables: [EditablePair] = []
    @Published var isEditingVariables = false
    @Published var response: APIResponseResult?
    @Published var isLoadingRoutes = false
    @Published var isSending = false
    @Published var loadError: String?
    @Published var sendError: String?
    @Published var metadataWarning: String?
    @Published var isGenericMode = false
    @Published var showsTabs = false
    @Published var draftMethod = "GET"
    @Published var draftPath = "/"

    static let methods = ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS", "HEAD"]

    static let adHocRouteID = "__ktstack_adhoc__"
    static let adHocRoute = APIRoute(
        method: "GET",
        uri: adHocRouteID,
        name: "New request",
        middleware: [],
        action: "",
        fields: [],
        rulesResolved: true
    )

    let routeIntrospection: any APIRouteIntrospecting
    var drafts: [String: RequestDraft] = [:]
    var siteKey = ""

    init(routeIntrospection: any APIRouteIntrospecting) {
        self.routeIntrospection = routeIntrospection
    }

    var siteDomain: String {
        siteKey
    }

    var activeVariableCount: Int {
        variableNames.count
    }

    var variableNames: [String] {
        variables
            .filter { $0.enabled && !$0.key.trimmingCharacters(in: .whitespaces).isEmpty }
            .map { $0.key.trimmingCharacters(in: .whitespaces) }
    }

    var webRoutes: [APIRoute] {
        filtered(routes.filter { !$0.isApi })
    }

    var apiRoutes: [APIRoute] {
        filtered(routes.filter(\.isApi))
    }

    var visibleRoutes: [APIRoute] {
        guard showsTabs else { return filtered(routes) }
        return tab == .web ? webRoutes : apiRoutes
    }

    var hasUnresolvedPathParams: Bool {
        requestDraft.pathParams.contains { $0.value.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    func filtered(_ source: [APIRoute]) -> [APIRoute] {
        let query = filter.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return source }
        return source.filter {
            $0.uri.lowercased().contains(query)
                || $0.method.lowercased().contains(query)
                || ($0.name?.lowercased().contains(query) ?? false)
        }
    }

    func newRequest() {
        select(Self.adHocRoute)
        draftMethod = "GET"
        draftPath = "/"
    }

    var normalizedDraftPath: String {
        let trimmed = draftPath.trimmingCharacters(in: .whitespaces)
        let path = trimmed.isEmpty ? "/" : trimmed
        return path.hasPrefix("/") ? path : "/" + path
    }

    func syncPathParams() {
        let names = Self.pathParamNames(in: normalizedDraftPath)
        let existing = Dictionary(requestDraft.pathParams.map { ($0.key, $0) }, uniquingKeysWith: { first, _ in first })
        var rebuilt: [EditablePair] = []
        var seen = Set<String>()
        for name in names where !seen.contains(name) {
            seen.insert(name)
            rebuilt.append(existing[name] ?? EditablePair(key: name, value: ""))
        }
        if rebuilt.map(\.key) != requestDraft.pathParams.map(\.key) {
            requestDraft.pathParams = rebuilt
        }
    }

    func select(_ route: APIRoute) {
        if let current = selected {
            drafts[current.id] = requestDraft
        }
        selected = route
        draftMethod = route.method
        draftPath = route.uri.hasPrefix("/") ? route.uri : "/" + route.uri
        response = nil
        sendError = nil
        requestDraft = drafts[route.id] ?? Self.defaultDraft(for: route)
    }

    static func pathParamNames(in uri: String) -> [String] {
        var names: [String] = []
        var current = ""
        var inside = false
        for ch in uri {
            if ch == "{" { inside = true; current = "" }
            else if ch == "}" {
                inside = false
                let cleaned = current.hasSuffix("?") ? String(current.dropLast()) : current
                if !cleaned.isEmpty { names.append(cleaned) }
            } else if inside {
                current.append(ch)
            }
        }
        return names
    }

    static func defaultDraft(for route: APIRoute) -> RequestDraft {
        var draft = RequestDraft()
        draft.headers = [EditablePair(key: "Accept", value: "application/json")]
        draft.pathParams = pathParamNames(in: route.uri).map { EditablePair(key: $0, value: "") }
        let writesBody = !["GET", "HEAD", "DELETE", "OPTIONS"].contains(route.method.uppercased())
        if writesBody, !route.fields.isEmpty {
            draft.bodyMode = .json
            draft.bodyText = bodySkeleton(fields: route.fields)
        }
        return draft
    }

    static func bodySkeleton(fields: [APIRouteRuleField]) -> String {
        let required = fields.filter(\.required)
        let chosen = required.isEmpty ? fields : required
        guard !chosen.isEmpty else { return "{\n  \n}" }
        let lines = chosen.map { "  \"\($0.name)\": \"\"" }.joined(separator: ",\n")
        return "{\n\(lines)\n}"
    }
}
