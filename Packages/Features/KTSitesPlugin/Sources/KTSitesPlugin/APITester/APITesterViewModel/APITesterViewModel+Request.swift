import Foundation
import KTPlatformContracts

extension APITesterViewModel {
    func send(site: SiteSummary) async {
        guard let route = selected, !isSending else { return }
        isSending = true
        sendError = nil
        response = nil
        saveVariables()
        drafts[route.id] = requestDraft
        do {
            let spec = try buildSpec(route: route, site: site)
            let client = APIRequestClient(timeout: timeoutSeconds)
            response = try await client.send(spec)
        } catch {
            sendError = error.localizedDescription
        }
        isSending = false
    }

    func buildSpec(route: APIRoute, site: SiteSummary) throws -> APIRequestSpec {
        guard let url = composeURL(route: route, site: site) else {
            throw APIRequestClient.RequestError(message: "Could not build a valid request URL.")
        }
        var headers = requestDraft.headers
            .filter { $0.enabled && !$0.key.trimmingCharacters(in: .whitespaces).isEmpty }
            .map { ($0.key, resolved($0.value)) }
        let body = encodedBody()
        if let body, !body.isEmpty, !headers.contains(where: { $0.0.lowercased() == "content-type" }) {
            headers.append(("Content-Type", contentType()))
        }
        return APIRequestSpec(method: draftMethod, url: url, headers: headers, body: body)
    }

    func composeURL(route _: APIRoute, site: SiteSummary) -> URL? {
        let scheme = site.secure ? "https" : "http"
        var path = normalizedDraftPath
        for param in requestDraft.pathParams {
            let raw = resolved(param.value)
            let value = raw.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? raw
            path = path.replacingOccurrences(of: "{\(param.key)?}", with: value)
            path = path.replacingOccurrences(of: "{\(param.key)}", with: value)
        }
        var components = URLComponents()
        components.scheme = scheme
        components.host = site.domain
        components.path = path
        let items = requestDraft.query
            .filter { $0.enabled && !$0.key.trimmingCharacters(in: .whitespaces).isEmpty }
            .map { URLQueryItem(name: $0.key, value: resolved($0.value)) }
        if !items.isEmpty { components.queryItems = items }
        return components.url
    }

    func encodedBody() -> Data? {
        switch requestDraft.bodyMode {
        case .none:
            return nil
        case .json:
            let text = resolved(requestDraft.bodyText)
            return text.isEmpty ? nil : text.data(using: .utf8)
        case .form:
            let fields = requestDraft.formFields
                .filter { $0.enabled && !$0.key.trimmingCharacters(in: .whitespaces).isEmpty }
                .map { ($0.key.trimmingCharacters(in: .whitespaces), resolved($0.value)) }
            return Self.encodeForm(fields)
        }
    }

    static func encodeForm(_ fields: [(String, String)]) -> Data? {
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
        let encoded = fields.map { key, value -> String in
            let encodedKey = key.addingPercentEncoding(withAllowedCharacters: allowed) ?? key
            let encodedValue = value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
            return "\(encodedKey)=\(encodedValue)"
        }
        let joined = encoded.joined(separator: "&")
        return joined.isEmpty ? nil : joined.data(using: .utf8)
    }

    func contentType() -> String {
        switch requestDraft.bodyMode {
        case .json: "application/json"
        case .form: "application/x-www-form-urlencoded"
        case .none: "application/octet-stream"
        }
    }
}
