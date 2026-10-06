import KTPlatformContracts
import KTPluginKit
import SwiftUI

extension SiteInspector {
    func domainCard(_ site: SiteSummary, settings: SiteSettingsModel) -> some View {
        InspectorCard(title: "Domain") {
            DomainEditor(domain: site.domain) { try vm.editDomain(site.id, $0) }
            AliasesEditor(site: site, model: settings)
            WildcardRow(site: site, model: settings)
        }
    }
}

private struct AliasesEditor: View {
    let site: SiteSummary
    @ObservedObject var model: SiteSettingsModel

    @State private var adding = false
    @FocusState private var focused: Bool

    private var tld: String {
        site.domain.split(separator: ".").last.map(String.init) ?? "test"
    }

    var body: some View {
        InspectorRow("Aliases") {
            VStack(alignment: .leading, spacing: 6) {
                if model.aliases.isEmpty {
                    InspectorHint("None")
                } else {
                    FlowLayout(spacing: 6) {
                        ForEach(model.aliases, id: \.self, content: pill)
                    }
                }
                if adding {
                    HStack(spacing: 6) {
                        TextField("alias.\(tld)", text: $model.aliasDraft)
                            .textFieldStyle(.roundedBorder).font(.jbMono(12.5))
                            .focused($focused)
                            .onSubmit(add)
                            .onExitCommand(perform: cancel)
                            .onAppear { focused = true }
                            .accessibilityLabel("New alias")
                        InspectorButton(title: "Add", action: add)
                        InspectorButton(title: "Cancel", style: .quiet, action: cancel)
                    }
                }
                if let error = model.aliasError { InspectorError(error) }
                if adding, site.secure {
                    InspectorHint("The HTTPS certificate is re-issued with the new aliases.")
                }
            }
        } trailing: {
            if !adding {
                InspectorButton(title: "Add") { adding = true }
            }
        }
    }

    private func pill(_ alias: String) -> some View {
        HStack(spacing: 5) {
            Text(alias).font(.jbMono(12)).foregroundStyle(KTColor.ink)
            Button { model.removeAlias(alias) } label: {
                Image(systemName: "xmark").font(.system(size: 8, weight: .bold))
                    .foregroundStyle(KTColor.muted)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove alias \(alias)")
        }
        .padding(.vertical, 3).padding(.horizontal, 7)
        .background(RoundedRectangle(cornerRadius: 5).fill(Color.primary.opacity(0.06)))
    }

    private func add() {
        model.addAlias()
        if model.aliasError == nil { adding = false }
    }

    private func cancel() {
        adding = false
        model.aliasDraft = ""
        model.aliasError = nil
    }
}

private struct WildcardRow: View {
    let site: SiteSummary
    @ObservedObject var model: SiteSettingsModel

    private var tip: String {
        let base = "For WordPress multisite (subdomain mode) and multi-tenant apps. A site or alias with its own domain still wins over the wildcard."
        return site.secure
            ? base + " HTTPS covers one level (tenant.\(site.domain)), not deeper names."
            : base
    }

    var body: some View {
        InspectorRow("Wildcard") {
            VStack(alignment: .leading, spacing: 3) {
                InspectorHint("Answer on *.\(site.domain)").ktTip(tip)
                if let error = model.wildcardError { InspectorError(error) }
            }
        } trailing: {
            InspectorSwitch(label: "Wildcard subdomains", isOn: model.wildcardSubdomains, action: model.toggleWildcard)
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
        InspectorRow("Domain") {
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
                        InspectorButton(title: "Save", action: commit)
                        InspectorButton(title: "Cancel", style: .quiet, action: cancel)
                    }
                } else {
                    InspectorValue(domain)
                }
                if let error { InspectorError(error) }
            }
        } trailing: {
            if !editing {
                InspectorButton(title: "Edit") {
                    draft = domain
                    error = nil
                    editing = true
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
