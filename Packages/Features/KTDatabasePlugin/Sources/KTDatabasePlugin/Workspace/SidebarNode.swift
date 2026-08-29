import Foundation

public enum SidebarNodeKind: Equatable, Hashable, Sendable {
    case connectionsHeader
    case connection(UUID)
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
    public let systemImage: String
    public let isGroup: Bool
    public var children: [SidebarNode]

    public init(
        id: String,
        kind: SidebarNodeKind,
        title: String,
        systemImage: String,
        isGroup: Bool,
        children: [SidebarNode] = []
    ) {
        self.id = id
        self.kind = kind
        self.title = title
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

    /// Dựng cây: nhóm Connections luôn có; Tables/Views/Queries chỉ khi đã chọn 1 kết nối + database.
    /// filter (không phân biệt hoa thường) lọc con của mọi nhóm; header giữ nguyên.
    static func build(
        profiles: [ConnectionProfile],
        selectedProfileID: UUID?,
        database: String?,
        objects: [TableInfo],
        favorites: [QueryFavorite],
        filter: String
    ) -> [SidebarNode] {
        let needle = filter.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        func matches(_ text: String) -> Bool {
            needle.isEmpty || text.lowercased().contains(needle)
        }

        let connections = profiles.filter { matches($0.name) }.map { profile in
            SidebarNode(
                id: "conn.\(profile.id.uuidString)",
                kind: .connection(profile.id),
                title: profile.name,
                systemImage: icon(for: profile.kind),
                isGroup: false
            )
        }
        var roots = [group(
            id: "grp.connections",
            kind: .connectionsHeader,
            title: "Connections",
            icon: "server.rack",
            children: connections
        )]

        guard selectedProfileID != nil, let database, !database.isEmpty else { return roots }

        let tables = objects.filter { !$0.isView && matches($0.name) }
            .map { objectNode(prefix: "tbl", kind: .table($0.name), name: $0.name, database: database, icon: "tablecells") }
        let views = objects.filter { $0.isView && matches($0.name) }
            .map { objectNode(prefix: "vw", kind: .view($0.name), name: $0.name, database: database, icon: "eye") }
        let queries = favorites.filter { matches($0.name) }.map { favorite in
            SidebarNode(
                id: "qry.\(favorite.id.uuidString)",
                kind: .query(favorite.id),
                title: favorite.name,
                systemImage: "star",
                isGroup: false
            )
        }

        roots.append(group(
            id: "grp.tables.\(database)",
            kind: .tablesHeader,
            title: "\(database) · Tables",
            icon: "cylinder",
            children: tables
        ))
        roots.append(group(
            id: "grp.views.\(database)",
            kind: .viewsHeader,
            title: "Views",
            icon: "eye",
            children: views
        ))
        roots.append(group(
            id: "grp.queries",
            kind: .queriesHeader,
            title: "Queries",
            icon: "star",
            children: queries
        ))
        return roots
    }

    private static func group(
        id: String, kind: SidebarNodeKind, title: String, icon: String, children: [SidebarNode]
    ) -> SidebarNode {
        SidebarNode(id: id, kind: kind, title: title, systemImage: icon, isGroup: true, children: children)
    }

    private static func objectNode(
        prefix: String, kind: SidebarNodeKind, name: String, database: String, icon: String
    ) -> SidebarNode {
        SidebarNode(id: "\(prefix).\(database).\(name)", kind: kind, title: name, systemImage: icon, isGroup: false)
    }
}
