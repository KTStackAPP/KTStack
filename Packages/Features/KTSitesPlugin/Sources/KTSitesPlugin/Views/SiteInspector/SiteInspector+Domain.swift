import KTPlatformContracts
import KTPluginKit
import SwiftUI

extension SiteInspector {
    func domainGroup(_ site: SiteSummary, settings: SiteSettingsModel) -> some View {
        InspectorGroup(title: "Domain") {
            InspectorField("Domain") {
                DomainEditor(domain: site.domain) { try vm.editDomain(site.id, $0) }
            }
            InspectorField("Aliases") { AliasesEditor(site: site, model: settings) }
            InspectorField("Wildcard") { WildcardToggle(site: site, model: settings) }
        }
    }
}

private struct AliasesEditor: View {
    let site: SiteSummary
    @ObservedObject var model: SiteSettingsModel

    private var tld: String {
        site.domain.split(separator: ".").last.map(String.init) ?? "test"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !model.aliases.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(model.aliases, id: \.self) { alias in
                        HStack(spacing: 6) {
                            Text(alias).font(.jbMono(12)).foregroundStyle(KTColor.ink2)
                            Button { model.removeAlias(alias) } label: {
                                Image(systemName: "xmark").font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(KTColor.muted)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Remove alias \(alias)")
                        }
                        .padding(.vertical, 3).padding(.horizontal, 9)
                        .background(Capsule().fill(KTColor.pillBg))
                    }
                }
            }
            HStack(spacing: 6) {
                TextField("alias.\(tld)", text: $model.aliasDraft)
                    .textFieldStyle(.roundedBorder).font(.jbMono(12.5))
                    .onSubmit(model.addAlias)
                    .accessibilityLabel("New alias")
                KTButton(title: "Add", kind: .secondary, action: model.addAlias)
            }
            if let error = model.aliasError { InspectorError(error) }
            if site.secure {
                InspectorCaption("Serving over HTTPS: the certificate is re-issued with the new aliases.")
            }
        }
    }
}

private struct WildcardToggle: View {
    let site: SiteSummary
    @ObservedObject var model: SiteSettingsModel

    private var hint: String {
        let base = "For WordPress multisite (subdomain mode) and multi-tenant apps. A site or alias with its own domain still wins over the wildcard."
        return site.secure
            ? base + " HTTPS covers one level (tenant.\(site.domain)), not deeper names."
            : base
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            KTToggle("Wildcard subdomains", isOn: model.wildcardSubdomains, action: model.toggleWildcard)
            InspectorCaption("Answer on *.\(site.domain) too")
            if let error = model.wildcardError { InspectorError(error) }
            InspectorCaption(hint).fixedSize(horizontal: false, vertical: true)
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
