import KTPlatformContracts
import KTPluginKit
import SwiftUI

/// Trang kết nối toàn khổ (chưa nối): header + tìm, section Engine trong KTStack / Kết nối của bạn /
/// Mở gần đây. Chọn card = selectedID; ⏎ hoặc nút Mở = onOpen; double-click card = onOpen.
struct ConnectionsPageView: View {
    let profiles: [ConnectionProfile]
    let statusFor: (UUID) -> ServerStatus
    let engineInstalled: (DatabaseEngine) -> Bool
    let engineRunning: (DatabaseEngine) -> Bool
    let recents: [RecentObject]
    @Binding var selectedID: UUID?
    let onOpen: (ConnectionProfile) -> Void
    let onOpenRecent: (RecentObject) -> Void
    let onNewConnection: () -> Void
    let onInstallEngine: (DatabaseEngine) -> Void
    let contextActions: (ConnectionProfile) -> [SidebarAction]

    @State private var search = ""

    private let columns = [GridItem(.adaptive(minimum: 260), spacing: 14)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                header
                managedSection
                userSection
                if !filteredRecents.isEmpty { recentSection }
                Spacer(minLength: 0)
                footer
            }
            .padding(28)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(KTEditorTheme.content)
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Kết nối cơ sở dữ liệu")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(KTEditorTheme.label)
                Text("Chọn một kết nối để duyệt bảng và chạy truy vấn, hoặc tạo kết nối mới.")
                    .font(.system(size: 12))
                    .foregroundStyle(KTEditorTheme.label2)
            }
            HStack(spacing: 10) {
                searchField
                Button(action: onNewConnection) {
                    Label("Kết nối mới", systemImage: "plus")
                        .font(.system(size: 12, weight: .medium))
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundStyle(KTEditorTheme.label3)
            TextField("Tìm theo tên, host, database…", text: $search)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
            if !search.isEmpty {
                Button { search = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(KTEditorTheme.label3)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .frame(maxWidth: 320)
        .background(KTEditorTheme.fieldBg, in: RoundedRectangle(cornerRadius: 7))
    }

    // MARK: Sections

    @ViewBuilder
    private var managedSection: some View {
        if !managed.isEmpty {
            section("Engine trong KTStack") {
                LazyVGrid(columns: columns, alignment: .leading, spacing: 14) {
                    ForEach(managed) { card($0) }
                }
            }
        }
    }

    private var userSection: some View {
        section("Kết nối của bạn") {
            LazyVGrid(columns: columns, alignment: .leading, spacing: 14) {
                ForEach(userProfiles) { card($0) }
                NewConnectionCard(action: onNewConnection)
            }
        }
    }

    private var recentSection: some View {
        section("Mở gần đây") {
            VStack(spacing: 4) {
                ForEach(filteredRecents) { object in
                    RecentObjectRow(
                        object: object,
                        profileName: profiles.first { $0.id == object.profileID }?.name ?? object.database,
                        onOpen: { onOpenRecent(object) }
                    )
                }
            }
        }
    }

    private func card(_ profile: ConnectionProfile) -> some View {
        let engine = profile.kind.engine
        return ConnectionCard(
            profile: profile,
            status: statusFor(profile.id),
            isSelected: selectedID == profile.id,
            engineInstalled: engine == nil ? false : engineInstalled(engine!),
            engineRunning: engine == nil ? false : engineRunning(engine!),
            onSelect: { selectedID = profile.id },
            onOpen: { onOpen(profile) },
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

    private func section(_ title: String, @ViewBuilder _ content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.6)
                .foregroundStyle(KTEditorTheme.label3)
            content()
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Text("⏎ Mở · ⌘0 Ẩn/hiện thanh bên · ⌘T Tab mới")
                .font(.system(size: 11))
                .foregroundStyle(KTEditorTheme.label3)
            Spacer(minLength: 0)
            if let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String {
                Text("KTStack \(version)")
                    .font(.system(size: 11))
                    .foregroundStyle(KTEditorTheme.label3)
            }
        }
        .padding(.top, 4)
    }

    // MARK: Derived

    private var managed: [ConnectionProfile] { filteredProfiles.filter(\.isManaged) }
    private var userProfiles: [ConnectionProfile] { filteredProfiles.filter { !$0.isManaged } }

    private var filteredProfiles: [ConnectionProfile] {
        let needle = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !needle.isEmpty else { return profiles }
        return profiles.filter {
            $0.name.lowercased().contains(needle) || $0.subtitle.lowercased().contains(needle)
        }
    }

    private var filteredRecents: [RecentObject] {
        let alive = recents.filter { object in profiles.contains { $0.id == object.profileID } }
        let needle = search.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !needle.isEmpty else { return alive }
        return alive.filter { $0.name.lowercased().contains(needle) }
    }
}
