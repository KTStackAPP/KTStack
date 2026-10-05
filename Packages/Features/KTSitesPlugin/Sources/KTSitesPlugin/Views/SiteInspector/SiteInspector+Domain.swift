import KTPlatformContracts
import KTPluginKit
import SwiftUI

extension SiteInspector {
    func domainGroup(_ site: SiteSummary) -> some View {
        InspectorGroup(title: "Domain") {
            InspectorField("Domain") {
                DomainEditor(domain: site.domain) { try vm.editDomain(site.id, $0) }
            }
            InspectorField("Aliases") {
                InspectorValue(site.aliases.isEmpty ? "None" : site.aliases.joined(separator: ", "), muted: site.aliases.isEmpty)
            }
            InspectorField("Wildcard") {
                InspectorValue(site.wildcardSubdomains ? "On" : "Off", muted: !site.wildcardSubdomains)
            }
        }
    }
}

private struct DomainEditor: View {
    let domain: String
    let save: (String) throws -> Void

    @State private var editing = false
    @State private var draft = ""
    @State private var error: String?
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if editing {
                HStack(spacing: 6) {
                    TextField("domain", text: $draft)
                        .textFieldStyle(.roundedBorder)
                        .font(.jbMono(12.5))
                        .focused($focused)
                        .onSubmit(commit)
                        .onExitCommand(perform: cancel)
                        .onAppear { focused = true }
                        .accessibilityLabel("Domain")
                    KTButton(title: "Save", kind: .secondary, action: commit)
                    KTButton(title: "Cancel", kind: .link, action: cancel)
                }
                if let error { InspectorError(error) }
            } else {
                HStack(spacing: 8) {
                    InspectorValue(domain)
                    KTButton(title: "Edit…", kind: .link) {
                        draft = domain
                        error = nil
                        editing = true
                    }
                }
            }
        }
        .onChange(of: domain) { _ in cancel() }
    }

    private func commit() {
        let next = SiteInspectorInput.domain(draft)
        guard next != domain else { return cancel() }
        do {
            try save(next)
            editing = false
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func cancel() {
        editing = false
        error = nil
        draft = domain
    }
}
