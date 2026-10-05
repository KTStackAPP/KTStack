import KTPlatformContracts
import SwiftUI

struct SiteSelectionSection: View {
    @Binding var plan: BackupPlan
    let sites: [SiteSummary]

    @State private var excludes: String

    init(plan: Binding<BackupPlan>, sites: [SiteSummary]) {
        _plan = plan
        self.sites = sites.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        _excludes = State(initialValue: plan.wrappedValue.siteExcludes.joined(separator: "\n"))
    }

    var body: some View {
        Section {
            Toggle("Include site source code", isOn: $plan.includeSites)
            if plan.includeSites {
                if sites.isEmpty {
                    Text("There are no sites yet.").foregroundStyle(.secondary)
                }
                ForEach(sites) { site in
                    Toggle(isOn: binding(site.id)) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(site.name)
                            Text(site.path).font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                        }
                    }
                }
                ForEach(missingIDs, id: \.self) { id in
                    Toggle("Removed site (\(id.uuidString.prefix(8)))", isOn: binding(id))
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Skip files matching (one pattern per line)")
                    TextEditor(text: $excludes)
                        .font(.system(.body, design: .monospaced))
                        .frame(height: 90)
                }
            }
        } header: {
            Text("Site Folders")
        } footer: {
            Text("Optional. Folder names match anywhere in the tree; paths with a slash match from the site root; * and ? are wildcards.")
        }
        .onChange(of: excludes) { text in
            plan.siteExcludes = text.split(whereSeparator: \.isNewline).map(String.init)
        }
    }

    private var missingIDs: [UUID] {
        let known = Set(sites.map(\.id))
        return plan.siteIDs.filter { !known.contains($0) }
    }

    private func binding(_ id: UUID) -> Binding<Bool> {
        Binding(
            get: { plan.siteIDs.contains(id) },
            set: { isOn in
                if isOn {
                    if !plan.siteIDs.contains(id) { plan.siteIDs.append(id) }
                } else {
                    plan.siteIDs.removeAll { $0 == id }
                }
            }
        )
    }
}
