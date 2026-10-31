import KTPlatformContracts
import KTPluginKit
import SwiftUI

struct SiteGroupField: View {
    let site: SiteSummary
    @ObservedObject var pane: SitesPaneModel
    let names: [String]
    let save: (String?) throws -> Void

    @State private var editing = false
    @State private var draft = ""
    @State private var error: String?
    @FocusState private var focused: Bool

    var body: some View {
        InspectorRow("Group") {
            VStack(alignment: .leading, spacing: 4) {
                if editing {
                    HStack(spacing: 6) {
                        TextField("Group name", text: $draft)
                            .textFieldStyle(.roundedBorder)
                            .font(.jbMono(12.5))
                            .focused($focused)
                            .onSubmit(commit)
                            .onExitCommand(perform: cancel)
                            .onAppear { focused = true }
                            .accessibilityLabel("New group name")
                        InspectorButton(title: "Save", action: commit)
                        InspectorButton(title: "Cancel", style: .quiet, action: cancel)
                    }
                } else {
                    picker
                }
                if let error { InspectorError(error) }
            }
        }
        .onAppear(perform: consumeRequest)
        .onChange(of: pane.pendingNewGroup) { _ in consumeRequest() }
    }

    private var picker: some View {
        Menu {
            ForEach(names, id: \.self) { name in
                Toggle(name, isOn: Binding(get: { site.group == name }, set: { _ in apply(name) }))
            }
            if !names.isEmpty { Divider() }
            Button("New Group…", action: startNew)
            if site.group != nil {
                Button("Remove from Group") { apply(nil) }
            }
        } label: {
            Text(site.group ?? "None").font(.jbMono(12.5))
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .accessibilityLabel("Group")
    }

    private func consumeRequest() {
        guard pane.pendingNewGroup == site.id else { return }
        pane.pendingNewGroup = nil
        startNew()
    }

    private func startNew() {
        draft = ""
        error = nil
        editing = true
    }

    private func apply(_ group: String?) {
        guard group != site.group else { return }
        do {
            try save(group)
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func commit() {
        guard !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return cancel() }
        do {
            try save(draft)
            editing = false
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func cancel() {
        editing = false
        error = nil
        draft = ""
    }
}
