import Foundation
import KTPlatformContracts

enum SitesFilter {
    static func visible(_ sites: [SiteSummary], kind: SiteKind?, query: String) -> [SiteSummary] {
        matching(sites, query: query).filter { kind == nil || $0.kind == kind }
    }

    // Đếm bỏ qua chip đang chọn để mỗi chip cho biết nếu bấm vào sẽ ra bao nhiêu site.
    static func counts(_ sites: [SiteSummary], query: String) -> [SiteKind?: Int] {
        let matched = matching(sites, query: query)
        var counts: [SiteKind?: Int] = [nil: matched.count]
        for site in matched {
            counts[site.kind, default: 0] += 1
        }
        return counts
    }

    // Site đang chọn biến mất thì chọn site đứng ở vị trí cũ, hoặc site cuối nếu danh sách ngắn lại.
    static func reconcile(selected: UUID?, previous: [UUID], visible: [UUID]) -> UUID? {
        if let selected, visible.contains(selected) { return selected }
        guard !visible.isEmpty else { return nil }
        if let selected, let index = previous.firstIndex(of: selected) {
            return visible[min(index, visible.count - 1)]
        }
        return visible.first
    }

    private static func matching(_ sites: [SiteSummary], query: String) -> [SiteSummary] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return sites }
        return sites.filter {
            $0.name.localizedCaseInsensitiveContains(trimmed) || $0.domain.localizedCaseInsensitiveContains(trimmed)
        }
    }
}
