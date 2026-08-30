import KTPlatformContracts
import KTPluginKit
import SwiftUI

/// Cột phải: toolbar (thêm, nhập, tìm) trên danh sách hai nhóm engine / kết nối đã lưu.
struct ConnectionListPane: View {
    let profiles: [ConnectionProfile]
    let statusFor: (UUID) -> ServerStatus
    let engineInstalled: (DatabaseEngine) -> Bool
    let compact: Bool
    @Binding var selection: UUID?
    @Binding var search: String
    let onCreate: () -> Void
    let onImportURL: () -> Void
    let onImportSite: () -> Void
    let onOpenPanel: () -> Void
    let onOpen: (ConnectionProfile) -> Void
    let onInstallEngine: (DatabaseEngine) -> Void
    let onStartEngine: (DatabaseEngine) -> Void
    let onEdit: (ConnectionProfile) -> Void
    let onDuplicate: (ConnectionProfile) -> Void
    let onDelete: (ConnectionProfile) -> Void

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider().overlay(KTColor.sep)
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(KTColor.contentBg)
    }

    private var toolbar: some View {
        HStack(spacing: KTSpacing.sm) {
            Button(action: onCreate) { Image(systemName: "plus") }
                .accessibilityLabel("Create Connection")
            AddFromExistingMenu(style: .icon, onImportURL: onImportURL, onImportSite: onImportSite)
            if compact {
                Button(action: onOpenPanel) { Image(systemName: "macwindow") }
                    .accessibilityLabel("Open Database Panel")
            }
            Spacer(minLength: KTSpacing.md)
            KTSearchField(text: $search, placeholder: "Search connections…")
                .frame(maxWidth: 280)
        }
        .padding(.horizontal, KTSpacing.xl)
        .padding(.vertical, KTSpacing.md)
    }

    @ViewBuilder
    private var content: some View {
        if managed.isEmpty, saved.isEmpty {
            EmptyStateView(
                symbol: "magnifyingglass",
                title: "No matches",
                message: "No engine or saved connection matches \"\(search)\"."
            )
        } else {
            List(selection: $selection) {
                if !managed.isEmpty {
                    Section("Engines in KTStack") {
                        ForEach(managed) { engineRow($0) }
                    }
                }
                Section("Your connections") {
                    if saved.isEmpty {
                        savedEmptyRow
                    } else {
                        ForEach(saved) { savedRow($0) }
                    }
                }
            }
            .listStyle(.inset)
        }
    }

    private var savedEmptyRow: some View {
        VStack(alignment: .leading, spacing: KTSpacing.sm) {
            Text(search.isEmpty ? "No saved connections" : "No matches")
                .font(KTType.label).foregroundStyle(KTColor.ink3)
            if search.isEmpty {
                KTButton(title: "Create Connection…", systemImage: "plus", action: onCreate)
            }
        }
        .padding(.vertical, KTSpacing.md)
    }

    private func engineRow(_ profile: ConnectionProfile) -> some View {
        let engine = profile.kind.engine
        let installed = engine.map(engineInstalled) ?? false
        return EngineConnectionRow(
            profile: profile,
            status: statusFor(profile.id),
            installed: installed,
            isSelected: selection == profile.id,
            onInstall: { if let engine { onInstallEngine(engine) } },
            onStart: { if let engine { onStartEngine(engine) } },
            onOpen: { onOpen(profile) }
        )
        .contentShape(Rectangle())
        .simultaneousGesture(TapGesture(count: 2).onEnded { if installed { onOpen(profile) } })
    }

    private func savedRow(_ profile: ConnectionProfile) -> some View {
        SavedConnectionRow(
            profile: profile,
            status: statusFor(profile.id),
            isSelected: selection == profile.id,
            onOpen: { onOpen(profile) }
        )
        .contentShape(Rectangle())
        .simultaneousGesture(TapGesture(count: 2).onEnded { onOpen(profile) })
        .contextMenu {
            Button("Edit…") { onEdit(profile) }
            Button("Duplicate") { onDuplicate(profile) }
            Divider()
            Button("Delete", role: .destructive) { onDelete(profile) }
        }
    }

    private var managed: [ConnectionProfile] {
        filtered(profiles.filter(\.isManaged))
    }

    private var saved: [ConnectionProfile] {
        filtered(profiles.filter { !$0.isManaged })
    }

    private func filtered(_ list: [ConnectionProfile]) -> [ConnectionProfile] {
        let needle = search.trimmingCharacters(in: .whitespaces).lowercased()
        guard !needle.isEmpty else { return list }
        return list.filter {
            $0.name.lowercased().contains(needle) || $0.subtitle.lowercased().contains(needle)
        }
    }
}
