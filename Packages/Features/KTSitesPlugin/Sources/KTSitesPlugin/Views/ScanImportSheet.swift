import Foundation
import KTPlatformContracts
import KTPluginKit
import SwiftUI

struct ScanImportSheet: View {
    let provisioning: any SiteProvisioning
    let sitesRoot: URL
    let tld: String
    let existingPaths: [String]
    let defaultPHPVersion: String
    @Environment(\.dismiss) private var dismiss

    @State private var scanned: [ScannedFolder] = []
    @State private var selected: Set<String> = [] // folder.path of ticked rows
    @State private var didScan = false

    var body: some View {
        VStack(alignment: .leading, spacing: KDSpacing.space3) {
            Text("Scan & Import Sites").font(KDFont.title)
            Text("Folders in \(sitesRoot.path)")
                .font(KDFont.footnote).foregroundStyle(.secondary)
                .lineLimit(1).truncationMode(.middle)

            content

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button(importTitle, action: importSelected)
                    .keyboardShortcut(.defaultAction)
                    .disabled(selected.isEmpty)
            }
        }
        .padding(KDSpacing.space4)
        .frame(width: 520)
        .task { await runScan() }
    }

    @ViewBuilder
    private var content: some View {
        if scanned.isEmpty {
            Text(didScan ? "No importable folders found in this root." : "Scanning…")
                .font(KDFont.body).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 120, alignment: .center)
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(scanned) { row in
                        rowView(row)
                        Divider()
                    }
                }
            }
            .frame(height: 280)
        }
    }

    private var importTitle: String {
        selected.isEmpty ? "Import" : "Import \(selected.count) Site\(selected.count == 1 ? "" : "s")"
    }

    private func rowView(_ row: ScannedFolder) -> some View {
        HStack(spacing: KDSpacing.space2) {
            Toggle("", isOn: binding(for: row)).labelsHidden().disabled(row.alreadyRegistered)
            Image(systemName: SiteVisuals.symbolName(for: row.kind)).foregroundStyle(.secondary).frame(width: 18)
            VStack(alignment: .leading, spacing: 1) {
                Text(row.folder.lastPathComponent).font(KDFont.body)
                Text(row.proposedDomain).font(KDFont.mono).foregroundStyle(.secondary)
            }
            Spacer()
            Text(row.alreadyRegistered ? "Added" : SiteVisuals.label(for: row.kind))
                .font(KDFont.footnote).foregroundStyle(.secondary)
        }
        .padding(.vertical, KDSpacing.space2)
        .opacity(row.alreadyRegistered ? 0.55 : 1)
    }

    private func binding(for row: ScannedFolder) -> Binding<Bool> {
        Binding(
            get: { selected.contains(row.folder.path) },
            set: { on in
                if on { selected.insert(row.folder.path) } else { selected.remove(row.folder.path) }
            }
        )
    }

    private func runScan() async {
        let result = provisioning.scan(root: sitesRoot, tld: tld, existingPaths: existingPaths)
        scanned = result
        selected = Set(result.filter { !$0.alreadyRegistered }.map(\.folder.path))
        didScan = true
    }

    private func importSelected() {
        for row in scanned where selected.contains(row.folder.path) && !row.alreadyRegistered {
            do {
                _ = try provisioning.registerFolder(row.folder, phpVersion: defaultPHPVersion)
            } catch {
                NSLog("KTStack: scan import skipped \(row.folder.lastPathComponent): \(error.localizedDescription)")
            }
        }
        dismiss()
    }
}
