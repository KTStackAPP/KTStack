import Foundation

public struct ExcludeMatcher: Sendable {
    public let patterns: [String]

    public init(patterns: [String]) {
        self.patterns = patterns
            .map { $0.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "/")) }
            .filter { !$0.isEmpty }
    }

    public func isExcluded(_ relativePath: String) -> Bool {
        let components = relativePath.split(separator: "/").map(String.init)
        guard !components.isEmpty else { return false }
        return patterns.contains { pattern in
            pattern.contains("/") ? matchesAnchored(pattern, components) : components.contains { glob(pattern, $0) }
        }
    }

    private func matchesAnchored(_ pattern: String, _ components: [String]) -> Bool {
        (1...components.count).contains { length in
            glob(pattern, components.prefix(length).joined(separator: "/"))
        }
    }

    private func glob(_ pattern: String, _ text: String) -> Bool {
        fnmatch(pattern, text, FNM_PATHNAME) == 0
    }
}
