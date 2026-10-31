import KTPluginKit
import SwiftUI

struct SitesGroupMenu: View {
    @Binding var selection: GroupFilter
    let names: [String]

    private var title: String {
        switch selection {
        case .all: "All Groups"
        case .ungrouped: "No Group"
        case let .named(name): name
        }
    }

    var body: some View {
        Menu {
            Picker("Group", selection: $selection) {
                Text("All Groups").tag(GroupFilter.all)
                Text("No Group").tag(GroupFilter.ungrouped)
                Divider()
                ForEach(names, id: \.self) { Text($0).tag(GroupFilter.named($0)) }
            }
            .pickerStyle(.inline)
            .labelsHidden()
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "folder").font(.system(size: 11))
                Text(title).lineLimit(1)
            }
            .font(.jbMono(12))
            .foregroundStyle(selection == .all ? KTColor.ink : KTColor.accent)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.visible)
        .fixedSize()
        .padding(.vertical, 4)
        .padding(.horizontal, 10)
        .background(Capsule().fill(KTColor.fieldBg))
        .overlay(Capsule().stroke(selection == .all ? KTColor.sep : KTColor.accent, lineWidth: 1))
        .accessibilityLabel("Filter by group")
    }
}
