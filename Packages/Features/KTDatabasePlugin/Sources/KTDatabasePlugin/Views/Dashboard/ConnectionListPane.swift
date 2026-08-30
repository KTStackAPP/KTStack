import KTPluginKit
import SwiftUI

/// Thân modal kết nối: toolbar (thêm, nhập, tìm) trên danh sách kết nối đã lưu.
struct ConnectionListPane: View {
    let profiles: [ConnectionProfile]
    let statusFor: (UUID) -> ServerStatus
    @Binding var selection: UUID?
    @Binding var search: String
    let onCreate: () -> Void
    let onImportURL: () -> Void
    let onImportSite: () -> Void
    let onOpen: (ConnectionProfile) -> Void
    let onEdit: (ConnectionProfile) -> Void
    let onDuplicate: (ConnectionProfile) -> Void
    let onDelete: (ConnectionProfile) -> Void

    var body: some View {
        VStack(spacing: 0) {
            Divider().overlay(KTColor.sep)
            toolbar
            Divider().overlay(KTColor.sep)
            content
        }
        .frame(height: 380)
    }

    private var toolbar: some View {
        HStack(spacing: KTSpacing.sm) {
            Button(action: onCreate) { Image(systemName: "plus") }
                .accessibilityLabel("Create Connection")
            AddFromExistingMenu(onImportURL: onImportURL, onImportSite: onImportSite)
            Spacer(minLength: KTSpacing.md)
            KTSearchField(text: $search, placeholder: "Search connections…")
                .frame(maxWidth: 260)
        }
        .padding(.horizontal, KTSpacing.xl)
        .padding(.vertical, KTSpacing.md)
    }

    @ViewBuilder
    private var content: some View {
        if filtered.isEmpty {
            emptyState
        } else {
            List(selection: $selection) {
                ForEach(filtered) { row($0) }
            }
            .listStyle(.inset)
        }
    }

    private var emptyState: some View {
        VStack(spacing: KTSpacing.md) {
            Text(search.isEmpty ? "No saved connections" : "No connection matches \"\(search)\"")
                .font(KTType.label).foregroundStyle(KTColor.ink3)
            if search.isEmpty {
                KTButton(title: "Create Connection…", systemImage: "plus", kind: .primary, action: onCreate)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func row(_ profile: ConnectionProfile) -> some View {
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

    // Host vẫn nằm trong bộ lọc dù hàng local không hiện nó.
    private var filtered: [ConnectionProfile] {
        let needle = search.trimmingCharacters(in: .whitespaces).lowercased()
        guard !needle.isEmpty else { return profiles }
        return profiles.filter {
            $0.name.lowercased().contains(needle)
                || $0.host.lowercased().contains(needle)
                || $0.database.lowercased().contains(needle)
        }
    }
}
