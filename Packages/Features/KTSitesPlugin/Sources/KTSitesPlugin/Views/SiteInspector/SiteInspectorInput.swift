import KTPlatformContracts
import KTStackCore

enum SiteInspectorInput {
    enum NodePort: Equatable {
        case clear
        case port(Int)
        case invalid
    }

    static func domain(_ draft: String) -> String {
        draft.trimmingCharacters(in: .whitespaces).lowercased()
    }

    static func nodePort(_ draft: String) -> NodePort {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .clear }
        guard let port = Int(trimmed), (1...65535).contains(port) else { return .invalid }
        return .port(port)
    }

    static func proxyDisplay(_ raw: String?) -> String {
        guard let raw else { return "" }
        if case let .success(target) = ProxyTarget.parse(raw) { return target.displayString }
        return raw
    }

    // Node và proxy cần upstream đang chạy mới mở được.
    static func canOpen(kind: SiteKind, serverRunning: Bool, upstreamRunning: Bool) -> Bool {
        switch kind {
        case .node, .proxy: serverRunning && upstreamRunning
        default: serverRunning
        }
    }
}
