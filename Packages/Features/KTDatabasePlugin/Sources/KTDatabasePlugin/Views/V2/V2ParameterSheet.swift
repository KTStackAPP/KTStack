import KTPluginKit
import SwiftUI

struct V2ParameterSheet: View {
    @ObservedObject var vm: DatabaseV2ViewModel
    let prompt: QueryParameterPrompt

    @State private var values: [String: String]

    init(vm: DatabaseV2ViewModel, prompt: QueryParameterPrompt) {
        self.vm = vm
        self.prompt = prompt
        _values = State(initialValue: Dictionary(uniqueKeysWithValues: prompt.names.map { ($0, "") }))
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Enter a value for each parameter. NULL and numbers are typed automatically.")
                        .font(.jbMono(11))
                        .foregroundStyle(KTEditorTheme.label3)
                    ForEach(prompt.names, id: \.self) { name in
                        row(name)
                    }
                }
                .padding(16)
            }
            footer
        }
        .frame(width: 460, height: min(160 + CGFloat(prompt.names.count) * 44, 520))
        .background(KTEditorTheme.window)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "curlybraces").font(.system(size: 12)).foregroundStyle(KTEditorTheme.accent)
            Text("Query Parameters").font(.jbMono(13)).foregroundStyle(KTEditorTheme.label)
            Spacer()
            V2Button(title: "Cancel") { vm.cancelParameterPrompt() }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .overlay(alignment: .bottom) { Divider().overlay(KTEditorTheme.separator) }
    }

    private func row(_ name: String) -> some View {
        HStack(spacing: 10) {
            Text(":\(name)")
                .font(.jbMono(12))
                .foregroundStyle(KTEditorTheme.accent)
                .frame(width: 120, alignment: .leading)
            TextField("value", text: binding(for: name))
                .textFieldStyle(.roundedBorder)
                .font(.jbMono(12))
        }
    }

    private var footer: some View {
        HStack {
            Spacer()
            V2Button(title: "Run", systemImage: "play.fill", kind: .primary) {
                Task { await vm.submitParameters(values) }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .overlay(alignment: .top) { Divider().overlay(KTEditorTheme.separator) }
    }

    private func binding(for name: String) -> Binding<String> {
        Binding(get: { values[name] ?? "" }, set: { values[name] = $0 })
    }
}
