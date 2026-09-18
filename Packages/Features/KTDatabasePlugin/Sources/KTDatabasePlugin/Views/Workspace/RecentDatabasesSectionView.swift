import KTPluginKit
import SwiftUI

struct RecentDatabasesSectionView: View {
    let recents: [RecentObject]
    let profiles: [ConnectionProfile]
    let onOpenRecent: (RecentObject) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("MỞ GẦN ĐÂY")
                .font(.footnote.weight(.semibold))
                .tracking(0.6)
                .foregroundStyle(.secondary)
            VStack(spacing: 4) {
                ForEach(recents) { object in
                    RecentObjectRow(
                        object: object,
                        profileName: profileDisplayName(for: object),
                        onOpen: { onOpenRecent(object) }
                    )
                }
            }
        }
    }

    private func profileDisplayName(for object: RecentObject) -> String {
        guard let profile = profiles.first(where: { $0.id == object.profileID }) else {
            return object.database
        }
        return profile.displayTitle(lastUsedDatabase: object.database)
    }
}
