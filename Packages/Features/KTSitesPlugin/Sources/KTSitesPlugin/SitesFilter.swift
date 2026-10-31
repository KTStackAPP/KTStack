import Foundation
import KTPlatformContracts

enum GroupFilter: Hashable {
    case all, ungrouped, named(String)

    func includes(_ site: SiteSummary) -> Bool {
        switch self {
        case .all: true
        case .ungrouped: site.group == nil
        case let .named(name): site.group == name
        }
    }
}

struct SitesSection: Identifiable, Equatable {
    let title: String?
    let sites: [SiteSummary]

    var id: String { title ?? "" }
}

enum SitesFilter {
    static func visible(_ sites: [SiteSummary], kind: SiteKind?, group: GroupFilter = .all, query: String) -> [SiteSummary] {
        matching(sites, query: query).filter { (kind == nil || $0.kind == kind) && group.includes($0) }
    }

    // Đếm bỏ qua chip đang chọn để mỗi chip cho biết nếu bấm vào sẽ ra bao nhiêu site.
    static func counts(_ sites: [SiteSummary], group: GroupFilter = .all, query: String) -> [SiteKind?: Int] {
        let matched = matching(sites, query: query).filter(group.includes)
        var counts: [SiteKind?: Int] = [nil: matched.count]
        for site in matched {
            counts[site.kind, default: 0] += 1
        }
        return counts
    }

    // Nhóm có tên xếp theo alphabet, site chưa có nhóm ở cuối; không ai có nhóm thì một section không tiêu đề.
    static func sections(_ sites: [SiteSummary]) -> [SitesSection] {
        let grouped = Dictionary(grouping: sites.filter { $0.group != nil }) { $0.group ?? "" }
        var sections = groupNames(sites).map { SitesSection(title: $0, sites: grouped[$0] ?? []) }
        let ungrouped = sites.filter { $0.group == nil }
        if !ungrouped.isEmpty { sections.append(SitesSection(title: nil, sites: ungrouped)) }
        return sections
    }

    static func groupNames(_ sites: [SiteSummary]) -> [String] {
        Set(sites.compactMap(\.group)).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
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
            $0.name.localizedCaseInsensitiveContains(trimmed)
                || $0.domain.localizedCaseInsensitiveContains(trimmed)
                || ($0.group?.localizedCaseInsensitiveContains(trimmed) ?? false)
                || ($0.kind == .php && "PHP \($0.phpVersion)".localizedCaseInsensitiveContains(trimmed))
        }
    }
}
