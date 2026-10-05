import AppKit
import SwiftUI

struct RemoteFolderBrowser: View {
    let title: String
    let rootName: String
    let client: any BackupDestinationClient
    let onChoose: ([RemoteFolder]) -> Void
    let onCancel: () -> Void

    @State private var path: [RemoteFolder] = []
    @State private var folders: [RemoteFolder] = []
    @State private var loading = false
    @State private var error: String?
    @State private var newFolderName = ""
    @State private var creating = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.headline)
            breadcrumb
            listing
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            HStack {
                TextField("New folder name", text: $newFolderName)
                Button("Create Folder", action: create)
                    .disabled(newFolderName.trimmingCharacters(in: .whitespaces).isEmpty || creating)
            }
            if let error {
                Text(error).font(.caption).foregroundStyle(.red)
            }
            HStack {
                Spacer()
                Button("Cancel", action: onCancel).keyboardShortcut(.cancelAction)
                Button("Use \"\(path.last?.name ?? rootName)\"") { onChoose(path) }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(16)
        .frame(width: 480, height: 440)
        .task(id: path) { await load() }
    }

    private var breadcrumb: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                Button(rootName) { path = [] }
                ForEach(Array(path.enumerated()), id: \.offset) { index, folder in
                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                    Button(folder.name) { path = Array(path.prefix(index + 1)) }
                }
            }
            .buttonStyle(.link)
        }
    }

    @ViewBuilder
    private var listing: some View {
        if loading {
            ProgressView()
        } else if folders.isEmpty {
            Text(error == nil ? "No folders here." : "Couldn't list folders.").foregroundStyle(.secondary)
        } else {
            List(folders) { folder in
                Button {
                    path.append(folder)
                } label: {
                    Label(folder.name, systemImage: "folder").frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func load() async {
        loading = true
        error = nil
        defer { loading = false }
        do {
            folders = try await client.listFolders(parent: path.last)
                .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        } catch {
            folders = []
            self.error = error.localizedDescription
        }
    }

    private func create() {
        let name = newFolderName.trimmingCharacters(in: .whitespaces)
        creating = true
        Task {
            defer { creating = false }
            do {
                let folder = try await client.createFolder(named: name, in: path.last)
                newFolderName = ""
                path.append(folder)
            } catch {
                self.error = error.localizedDescription
            }
        }
    }
}
