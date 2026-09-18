import KTPlatformContracts
import KTPluginKit
import SwiftUI

struct ConnectionsPageView: View {
    let profiles: [ConnectionProfile]
    let statusFor: (UUID) -> ServerStatus
    let engineInstalled: (DatabaseEngine) -> Bool
    let engineRunning: (DatabaseEngine) -> Bool
    let recents: [RecentObject]
    var lastDatabaseFor: (UUID) -> String? = { _ in nil }
    var recentDatabasesFor: (UUID) -> [String] = { _ in [] }
    @Binding var selectedID: UUID?
    let onOpen: (ConnectionProfile) -> Void
    var onOpenDatabase: ((ConnectionProfile, String) -> Void)? = nil
    let onOpenRecent: (RecentObject) -> Void
    let onNewConnection: () -> Void
    let onInstallEngine: (DatabaseEngine) -> Void
    let contextActions: (ConnectionProfile) -> [SidebarAction]

    @State private var search = ""

    private let columns = [GridItem(.adaptive(minimum: 270), spacing: 12)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                ConnectionsPageHeader(search: $search, onNewConnection: onNewConnection)
                if !managed.isEmpty {
                    sectionView(title: "Managed Engines") {
                        LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                            ForEach(managed) { card($0) }
                        }
                    }
                }
                sectionView(title: "Your Connections") {
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                        ForEach(userProfiles) { card($0) }
                        NewConnectionCard(action: onNewConnection)
                    }
                }
                if !filteredRecents.isEmpty {
                    RecentDatabasesSectionView(
                        recents: filteredRecents,
                        profiles: profiles,
                        onOpenRecent: onOpenRecent
                    )
                }
                Spacer(minLength: 0)
                ConnectionsPageFooter()
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private func card(_ profile: ConnectionProfile) -> some View {
        let engine = profile.kind.engine
        let lastDB = lastDatabaseFor(profile.id)
        let recents = recentDatabasesFor(profile.id)
        return ConnectionCard(
            profile: profile,
            status: statusFor(profile.id),
            isSelected: selectedID == profile.id,
            engineInstalled: engine == nil ? false : engineInstalled(engine!),
            engineRunning: engine == nil ? false : engineRunning(engine!),
            lastUsedDatabase: lastDB,
            recentDatabases: recents,
            onSelect: { selectedID = profile.id },
            onOpen: { onOpen(profile) },
            onOpenDatabase: { db in onOpenDatabase?(profile, db) },
            onInstallEngine: { if let engine { onInstallEngine(engine) } }
        )
        .contextMenu { menu(for: profile) }
    }

    @ViewBuilder
    private func menu(for profile: ConnectionProfile) -> some View {
        ForEach(Array(contextActions(profile).enumerated()), id: \.offset) { _, action in
            Button(role: action.isDestructive ? .destructive : nil, action: action.handler) {
                Text(action.title)
            }
        }
    }

    private func sectionView<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.footnote.weight(.semibold))
                .tracking(0.6)
                .foregroundStyle(.secondary)
            content()
        }
    }

    private var managed: [ConnectionProfile] { filteredProfiles.filter(\.isManaged) }
    private var userProfiles: [ConnectionProfile] { filteredProfiles.filter { !$0.isManaged } }

    private var filteredProfiles: [ConnectionProfile] {
        let needle = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !needle.isEmpty else { return profiles }
        return profiles.filter { profile in
            let last = lastDatabaseFor(profile.id)
            let title = profile.displayTitle(lastUsedDatabase: last).lowercased()
            let sub = profile.displaySubtitle(lastUsedDatabase: last).lowercased()
            let recents = recentDatabasesFor(profile.id).map { $0.lowercased() }
            return profile.name.lowercased().contains(needle)
                || title.contains(needle)
                || sub.contains(needle)
                || profile.database.lowercased().contains(needle)
                || recents.contains(where: { $0.contains(needle) })
        }
    }

    private var filteredRecents: [RecentObject] {
        let alive = recents.filter { object in profiles.contains { $0.id == object.profileID } }
        let needle = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !needle.isEmpty else { return alive }
        return alive.filter { $0.name.lowercased().contains(needle) || $0.database.lowercased().contains(needle) }
    }
}
