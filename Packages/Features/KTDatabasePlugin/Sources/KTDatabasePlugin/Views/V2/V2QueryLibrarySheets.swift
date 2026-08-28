import KTPluginKit
import SwiftUI

struct V2HistorySheet: View {
    @ObservedObject var vm: DatabaseV2ViewModel

    var body: some View {
        VStack(spacing: 0) {
            header
            if vm.queryHistory.isEmpty {
                emptyState("No query history", "Run SQL to build a local recall list.")
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(vm.queryHistory) { entry in
                            row(entry)
                            Divider().overlay(KTEditorTheme.separator)
                        }
                    }
                }
            }
        }
        .frame(width: 620, height: 460)
        .background(KTEditorTheme.window)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "clock.arrow.circlepath").font(.system(size: 12)).foregroundStyle(KTEditorTheme.accent)
            Text("Query History").font(.jbMono(13)).foregroundStyle(KTEditorTheme.label)
            Spacer()
            V2Button(title: "Clear", systemImage: "trash", kind: .danger) { vm.clearHistory() }
                .disabled(vm.queryHistory.isEmpty)
            V2Button(title: "Done") { vm.activeQuerySheet = nil }
        }
        .padding(.horizontal, 16).padding(.vertical, 11)
        .overlay(alignment: .bottom) { Divider().overlay(KTEditorTheme.separator) }
    }

    private func row(_ entry: QueryHistoryEntry) -> some View {
        Button { vm.recall(entry) } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.sql).font(.jbMono(12)).foregroundStyle(KTEditorTheme.label).lineLimit(2)
                HStack(spacing: 8) {
                    Text(entry.connectionLabel)
                    if let database = entry.database { Text(database) }
                    Text(entry.ranAt.formatted(date: .abbreviated, time: .shortened))
                }
                .font(.jbMono(10)).foregroundStyle(KTEditorTheme.label3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16).padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func emptyState(_ title: String, _ message: String) -> some View {
        VStack(spacing: 6) {
            Spacer()
            Text(title).font(.jbMono(13)).foregroundStyle(KTEditorTheme.label2)
            Text(message).font(.jbMono(11)).foregroundStyle(KTEditorTheme.label3)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

struct V2FavoritesSheet: View {
    @ObservedObject var vm: DatabaseV2ViewModel
    @State private var name = ""

    var body: some View {
        VStack(spacing: 0) {
            header
            saveBar
            Divider().overlay(KTEditorTheme.separator)
            if vm.favorites.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(vm.favorites) { favorite in
                            row(favorite)
                            Divider().overlay(KTEditorTheme.separator)
                        }
                    }
                }
            }
        }
        .frame(width: 620, height: 460)
        .background(KTEditorTheme.window)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "star").font(.system(size: 12)).foregroundStyle(KTEditorTheme.accent)
            Text("Favorites").font(.jbMono(13)).foregroundStyle(KTEditorTheme.label)
            Spacer()
            V2Button(title: "Done") { vm.activeQuerySheet = nil }
        }
        .padding(.horizontal, 16).padding(.vertical, 11)
        .overlay(alignment: .bottom) { Divider().overlay(KTEditorTheme.separator) }
    }

    private var saveBar: some View {
        HStack(spacing: 10) {
            TextField("Name the current query", text: $name)
                .textFieldStyle(.roundedBorder).font(.jbMono(12))
            V2Button(title: "Save", systemImage: "plus", kind: .primary) {
                vm.saveFavorite(name: name)
                name = ""
            }
            .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
    }

    private func row(_ favorite: QueryFavorite) -> some View {
        HStack(spacing: 8) {
            Button { vm.recall(favorite) } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(favorite.name).font(.jbMono(12, .bold)).foregroundStyle(KTEditorTheme.label).lineLimit(1)
                    Text(favorite.sql).font(.jbMono(11)).foregroundStyle(KTEditorTheme.label3).lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Button { vm.deleteFavorite(id: favorite.id) } label: {
                Image(systemName: "trash").font(.system(size: 11)).foregroundStyle(KTEditorTheme.label3)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Spacer()
            Text("No favorites yet").font(.jbMono(13)).foregroundStyle(KTEditorTheme.label2)
            Text("Name the current query above to save it.").font(.jbMono(11)).foregroundStyle(KTEditorTheme.label3)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}
