import KTPluginKit
import SwiftUI

struct WorkspaceDatabaseHeader: View {
    @ObservedObject var vm: DatabaseV2ViewModel
    let onSelectDatabase: (String) -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "cylinder.split.1x2")
                .font(.subheadline)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color.accentColor)
            Menu {
                ForEach(vm.databases) { db in
                    Button {
                        onSelectDatabase(db.name)
                    } label: {
                        if db.name == vm.selectedDatabase {
                            Label(db.name, systemImage: "checkmark")
                        } else {
                            Text(db.name)
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(vm.selectedDatabase ?? "—")
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    if !vm.databases.isEmpty {
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}
