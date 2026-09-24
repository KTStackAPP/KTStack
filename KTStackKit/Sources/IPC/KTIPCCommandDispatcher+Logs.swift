import Foundation
import KTStackCore

extension KTIPCCommandDispatcher {
    static let maxLogLines = 2000

    func handleRecentLogs(request: KTIPCRequest) async -> KTIPCResponse {
        let sourceID = request.params?["source"] ?? "nginx-error"
        let lineCount = min(max(Int(request.params?["lines"] ?? "50") ?? 50, 1), Self.maxLogLines)
        let context = await logContext()
        let sources = LogCatalog(paths: AppSupportPaths()).sources(siteDomains: context.domains, phpVersions: context.php)
        guard let source = sources.first(where: { $0.id == sourceID }) else {
            let valid = sources.map(\.id).joined(separator: ", ")
            return .fail("Unknown log source '\(sourceID)'. Available: \(valid)", id: request.id)
        }
        guard let content = try? String(contentsOf: source.url, encoding: .utf8) else {
            return .ok("No logs yet for \(source.id)", id: request.id)
        }
        let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
        return .ok(lines.suffix(lineCount).joined(separator: "\n"), id: request.id)
    }

    private func logContext() async -> (domains: [String], php: [String]) {
        guard let server = await serverProvider() else { return ([], []) }
        return await MainActor.run { (server.registry.sites.map(\.domain), server.phpVersions) }
    }
}
