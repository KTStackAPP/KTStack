import KTPlatformContracts
import KTPluginKit
import SwiftUI

// Giữ một SiteSettingsModel cho mỗi site, dùng chung cho nhóm Domain và Advanced.
struct SiteSettingsHost<Content: View>: View {
    @StateObject private var model: SiteSettingsModel
    private let content: (SiteSettingsModel) -> Content

    init(site: SiteSummary, vm: SitesViewModel, @ViewBuilder content: @escaping (SiteSettingsModel) -> Content) {
        _model = StateObject(wrappedValue: SiteSettingsModel(
            site: site,
            validateAliases: { try vm.validateAliases($0, for: site.id) },
            setAliases: { try vm.setAliases(site.id, $0) },
            setWildcardSubdomains: { try vm.setWildcardSubdomains(site.id, $0) },
            setEnvVars: { try vm.setEnvVars(site.id, $0) },
            saveDirectives: { try await vm.saveFrontDirectives(site.id, $0) }
        ))
        self.content = content
    }

    var body: some View {
        content(model)
    }
}

struct SiteAdvancedSection: View {
    let site: SiteSummary
    @ObservedObject var model: SiteSettingsModel
    let onOpenLogs: () -> Void

    var body: some View {
        InspectorGroup(title: "Advanced") {
            if model.showsEnv { envEditor }
            directivesEditor
            KTButton(title: "Open Logs", kind: .link, action: onOpenLogs)
        }
    }

    private func subheading(_ title: String) -> some View {
        Text(title).font(.jbMono(12)).foregroundStyle(KTColor.ink3)
    }

    private var envEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            subheading("Environment variables")
            ForEach($model.envRows) { $row in
                HStack(spacing: 8) {
                    TextField("KEY", text: $row.key)
                        .textFieldStyle(.roundedBorder).font(.jbMono(12.5)).frame(width: 120)
                    TextField("value", text: $row.value)
                        .textFieldStyle(.roundedBorder).font(.jbMono(12.5))
                    Button { model.removeEnvRow(row.id) } label: {
                        Image(systemName: "minus.circle").foregroundStyle(KTColor.muted)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Remove variable")
                }
            }
            HStack(spacing: 10) {
                KTButton(title: "Add variable", systemImage: "plus", kind: .link, action: model.addEnvRow)
                Spacer()
                if model.envSaved {
                    Text("Saved").font(.jbMono(11.5)).foregroundStyle(KTColor.online)
                }
                KTButton(title: "Save", kind: .secondary, action: model.saveEnv)
            }
            if let error = model.envError { InspectorError(error) }
            InspectorCaption(envHint)
        }
    }

    private var envHint: String {
        site.kind == .node
            ? "Exported when you Start in Terminal."
            : "Passed to PHP through fastcgi_param."
    }

    private var directivesEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            subheading("Nginx directives")
            TextEditor(text: $model.directives)
                .font(.jbMono(12.5))
                .frame(minHeight: 140)
                .padding(6)
                .background(RoundedRectangle(cornerRadius: 8).fill(KTColor.fieldBg))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(KTColor.sep, lineWidth: 0.5))
                .accessibilityLabel("Nginx directives")
            Text("Inserted into this site's front nginx server block. Checked with nginx -t before reload; a rejected save keeps the previous config.")
                .font(KTType.caption).foregroundStyle(KTColor.muted)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                if let note = model.directivesNote {
                    Text(note).font(.jbMono(11.5)).foregroundStyle(KTColor.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                KTButton(title: "Save", kind: .secondary, isLoading: model.isSavingDirectives) {
                    Task { await model.saveDirectives() }
                }
                .disabled(model.isSavingDirectives)
            }
            if let error = model.directivesError { InspectorError(error) }
        }
    }
}
