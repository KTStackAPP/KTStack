import Foundation

public enum SidebarNodeKind: Equatable, Hashable, Sendable {
    case tablesHeader
    case viewsHeader
    case queriesHeader
    case table(String)
    case view(String)
    case query(UUID)
}

/// Node thuần cho cây sidebar: builder tạo ra, NSOutlineView chỉ đọc. id nhúng kind+db+name để
/// bảng và view cùng tên không trùng khóa (rủi ro phase 2).
public struct SidebarNode: Identifiable, Equatable, Sendable {
    public let id: String
    public let kind: SidebarNodeKind
    public let title: String
    public let subtitle: String?
    public let systemImage: String
    public let isGroup: Bool
    public var children: [SidebarNode]

    public init(
        id: String,
        kind: SidebarNodeKind,
        title: String,
        subtitle: String? = nil,
        systemImage: String,
        isGroup: Bool,
        children: [SidebarNode] = []
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.isGroup = isGroup
        self.children = children
    }
}

public extension SidebarNode {
    static func icon(for kind: DatabaseKind) -> String {
        switch kind {
        case .mysql: "cylinder.split.1x2"
        case .mongodb: "doc.text"
        case .postgres, .sqlite: "cylinder"
        }
    }

    /// Dựng cây object của kết nối trong tab: ba nhóm Tables/Views/Queries, subtitle = số lượng con.
    /// filter (không phân biệt hoa thường) chỉ lọc con; header luôn hiện.
    static func build(
        objects: [TableInfo],
        favorites: [QueryFavorite],
        filter: String
    ) -> [SidebarNode] {
        let needle = filter.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        func matches(_ text: String) -> Bool {
            needle.isEmpty || text.lowercased().contains(needle)
        }

        let tables = objects.filter { !$0.isView && matches($0.name) }
            .map { objectNode(prefix: "tbl", kind: .table($0.name), name: $0.name, icon: "tablecells") }
        let views = objects.filter { $0.isView && matches($0.name) }
            .map { objectNode(prefix: "vw", kind: .view($0.name), name: $0.name, icon: "eye") }
        let queries = favorites.filter { matches($0.name) }.map { favorite in
            SidebarNode(
                id: "qry.\(favorite.id.uuidString)",
                kind: .query(favorite.id),
                title: favorite.name,
                systemImage: "star",
                isGroup: false
            )
        }

        return [
            group(id: "grp.tables", kind: .tablesHeader, title: "Tables", icon: "cylinder", children: tables),
            group(id: "grp.views", kind: .viewsHeader, title: "Views", icon: "eye", children: views),
            group(id: "grp.queries", kind: .queriesHeader, title: "Queries", icon: "star", children: queries),
        ]
    }

    private static func group(
        id: String, kind: SidebarNodeKind, title: String, icon: String, children: [SidebarNode]
    ) -> SidebarNode {
        SidebarNode(
            id: id, kind: kind, title: title, subtitle: "\(children.count)",
            systemImage: icon, isGroup: true, children: children
        )
    }

    private static func objectNode(
        prefix: String, kind: SidebarNodeKind, name: String, icon: String
    ) -> SidebarNode {
        SidebarNode(id: "\(prefix).\(name)", kind: kind, title: name, systemImage: icon, isGroup: false)
    }
}
