import KTPlatformContracts
import KTPluginKit
import SwiftUI

struct SiteSettingsSheet: View {
    let site: SiteSummary
    @StateObject private var model: SiteSettingsModel
    @Environment(\.dismiss) private var dismiss

    init(site: SiteSummary, vm: SitesViewModel) {
        self.site = site
        _model = StateObject(wrappedValue: SiteSettingsModel(
            site: site,
            validateAliases: { try vm.validateAliases($0, for: site.id) },
            setAliases: { try vm.setAliases(site.id, $0) },
            setEnvVars: { try vm.setEnvVars(site.id, $0) },
            saveDirectives: { try await vm.saveFrontDirectives(site.id, $0) }
        ))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().padding(.horizontal, 20)
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    aliasesSection
                    if model.showsEnv { envSection }
                    directivesSection
                }
                .padding(20)
            }
            Divider()
            HStack {
                Spacer()
                KTButton(title: "Done", kind: .primary) { dismiss() }
            }
            .padding(.horizontal, 20).padding(.vertical, 14)
        }
        .frame(width: 640)
        .frame(maxHeight: 620)
        .background(KTColor.contentBg)
    }

    private var header: some View {
        HStack(spacing: 11) {
            KTIconTile(tint: SiteVisuals.tint(for: site.kind), size: 34) {
                KTSiteGlyph(kind: SiteVisuals.kind(for: site.kind), size: 17, color: SiteVisuals.tint(for: site.kind).fg)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(site.name).font(KTType.label).foregroundStyle(KTColor.ink).lineLimit(1)
                Text(site.domain).font(KTType.caption).foregroundStyle(KTColor.muted).lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20).padding(.vertical, 16)
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title.uppercased())
            .font(KTType.sectionLabel)
            .tracking(KTType.sectionLabelTracking)
            .foregroundStyle(KTColor.faint)
    }

    private func errorText(_ text: String) -> some View {
        Text(text).font(.jbMono(12)).foregroundStyle(KTColor.danger)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var aliasesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Alias domains")
            if !model.aliases.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(model.aliases, id: \.self) { alias in
                        HStack(spacing: 6) {
                            Text(alias).font(.jbMono(12.5)).foregroundStyle(KTColor.ink2)
                            Button { model.removeAlias(alias) } label: {
                                Image(systemName: "xmark").font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(KTColor.muted)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Remove alias \(alias)")
                        }
                        .padding(.vertical, 4).padding(.horizontal, 10)
                        .background(Capsule().fill(KTColor.pillBg))
                    }
                }
            }
            HStack(spacing: 8) {
                TextField("alias.\(tld)", text: $model.aliasDraft)
                    .textFieldStyle(.roundedBorder).font(.jbMono(12.5))
                    .onSubmit(model.addAlias)
                KTButton(title: "Add", kind: .secondary, action: model.addAlias)
            }
            if let error = model.aliasError { errorText(error) }
            if site.secure {
                Text("Serving over HTTPS: the certificate is re-issued with the new aliases.")
                    .font(.jbMono(11.5)).foregroundStyle(KTColor.faint)
            }
        }
    }

    private var tld: String {
        site.domain.split(separator: ".").last.map(String.init) ?? "test"
    }

    private var envSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Environment variables")
            ForEach($model.envRows) { $row in
                HStack(spacing: 8) {
                    TextField("KEY", text: $row.key)
                        .textFieldStyle(.roundedBorder).font(.jbMono(12.5)).frame(width: 200)
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
            if let error = model.envError { errorText(error) }
            Text(envHint).font(.jbMono(11.5)).foregroundStyle(KTColor.faint)
        }
    }

    private var envHint: String {
        site.kind == .node
            ? "Exported when you Start in Terminal."
            : "Passed to PHP through fastcgi_param."
    }

    private var directivesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionLabel("Nginx directives")
            TextEditor(text: $model.directives)
                .font(.jbMono(12.5))
                .frame(minHeight: 160)
                .padding(6)
                .background(RoundedRectangle(cornerRadius: 8).fill(KTColor.fieldBg))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(KTColor.sep, lineWidth: 0.5))
            Text("Inserted into this site's front nginx server block. Checked with nginx -t before reload; a rejected save keeps the previous config.")
                .font(.jbMono(11.5)).foregroundStyle(KTColor.faint)
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
            if let error = model.directivesError { errorText(error) }
        }
    }
}

// Wrap các pill alias xuống dòng khi tràn chiều ngang.
private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0; y += rowHeight + spacing; rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth == .infinity ? x : maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) {
        let maxWidth = proposal.width ?? bounds.width
        var x = bounds.minX, y = bounds.minY, rowHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.minX + maxWidth, x > bounds.minX {
                x = bounds.minX; y += rowHeight + spacing; rowHeight = 0
            }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
