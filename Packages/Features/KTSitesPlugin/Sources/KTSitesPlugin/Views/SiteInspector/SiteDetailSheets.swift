import KTPlatformContracts
import KTPluginKit
import SwiftUI

struct DetailSheet<Content: View, Buttons: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let content: Content
    @ViewBuilder let buttons: (@escaping () -> Void) -> Buttons

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.jbMono(15, .semibold)).foregroundStyle(KTColor.ink)
                Text(subtitle).font(.jbMono(12)).foregroundStyle(KTColor.muted)
            }
            content
            HStack(spacing: 8) {
                Spacer()
                buttons { dismiss() }
            }
        }
        .padding(20)
    }
}

struct EnvironmentSheet: View {
    let site: SiteSummary
    @ObservedObject var model: SiteSettingsModel

    var body: some View {
        DetailSheet(title: "Environment variables", subtitle: site.domain) {
            VStack(alignment: .leading, spacing: 8) {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach($model.envRows) { $row in
                            HStack(spacing: 8) {
                                TextField("KEY", text: $row.key)
                                    .textFieldStyle(.roundedBorder).font(.jbMono(12.5)).frame(width: 160)
                                TextField("value", text: $row.value)
                                    .textFieldStyle(.roundedBorder).font(.jbMono(12.5))
                                Button { model.removeEnvRow(row.id) } label: {
                                    Image(systemName: "minus.circle").foregroundStyle(KTColor.muted)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Remove variable")
                            }
                        }
                    }
                }
                .frame(minHeight: 120, maxHeight: 280)
                KTButton(title: "Add variable", systemImage: "plus", kind: .link, action: model.addEnvRow)
                if let error = model.envError { InspectorError(error) }
                InspectorHint(site.kind == .node ? "Exported when you Start in Terminal." : "Passed to PHP through fastcgi_param.")
            }
        } buttons: { dismiss in
            KTButton(title: "Cancel", kind: .secondary) {
                model.resetEnv(site.envVars)
                dismiss()
            }
            .keyboardShortcut(.cancelAction)
            KTButton(title: "Save", kind: .primary) {
                model.saveEnv()
                if model.envError == nil { dismiss() }
            }
            .keyboardShortcut(.defaultAction)
        }
        .frame(width: 560)
    }
}

struct DirectivesSheet: View {
    let site: SiteSummary
    @ObservedObject var model: SiteSettingsModel

    var body: some View {
        DetailSheet(title: "Nginx directives", subtitle: site.domain) {
            VStack(alignment: .leading, spacing: 8) {
                TextEditor(text: $model.directives)
                    .font(.jbMono(12.5))
                    .frame(minHeight: 220)
                    .padding(6)
                    .background(RoundedRectangle(cornerRadius: 8).fill(KTColor.fieldBg))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(KTColor.sep, lineWidth: 1))
                    .accessibilityLabel("Nginx directives")
                InspectorHint("Inserted into this site's front nginx server block. Checked with nginx -t before reload; a rejected save keeps the previous config.")
                if let note = model.directivesNote { InspectorHint(note) }
                if let error = model.directivesError { InspectorError(error) }
            }
        } buttons: { dismiss in
            KTButton(title: "Cancel", kind: .secondary) {
                model.resetDirectives(site.frontDirectives)
                dismiss()
            }
            .keyboardShortcut(.cancelAction)
            KTButton(title: "Save", kind: .primary, isLoading: model.isSavingDirectives) {
                Task {
                    await model.saveDirectives()
                    if model.directivesError == nil { dismiss() }
                }
            }
            .disabled(model.isSavingDirectives)
        }
        .frame(width: 600)
    }
}
