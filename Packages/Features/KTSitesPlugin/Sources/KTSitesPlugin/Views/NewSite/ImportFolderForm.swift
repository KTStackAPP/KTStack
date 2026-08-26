import AppKit
import KTPlatformContracts
import KTPluginKit
import SwiftUI

struct ImportFolderForm: View {
    @Binding var folder: URL?
    @Binding var name: String
    @Binding var phpVersion: String
    @Binding var serveHTTPS: Bool
    @Binding var createDatabase: Bool
    let availableVersions: [String]
    let provisioning: any SiteProvisioning
    let tld: String
    @State private var advanced = false
    @State private var detectedKind: SiteKind?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            SiteFormControls.row("Folder", topAligned: true) {
                VStack(alignment: .leading, spacing: 7) {
                    SiteFormControls.fieldBox {
                        SiteFormControls.smallTile(KTIconTint.cube) {
                            Image(systemName: "folder").font(.system(size: 14, weight: .regular))
                        }
                        Text(folder?.path ?? "No folder selected")
                            .font(.jbMono(13.5)).foregroundStyle(folder == nil ? KTColor.muted : KTColor.ink)
                            .lineLimit(1).truncationMode(.middle)
                        Spacer(minLength: 0)
                        KTButton(title: "Choose…", kind: .secondary) { pickFolder() }
                    }
                    SiteFormControls.helper("KTStack serves this folder in place — files are never moved or copied.")
                }
            }

            SiteFormControls.row("Domain", topAligned: true) {
                VStack(alignment: .leading, spacing: 7) {
                    SiteFormControls.fieldBox {
                        SiteFormControls.smallTile(KTIconTint.code) {
                            KTSiteGlyph(kind: .code, size: 15, color: KTIconTint.code.fg)
                        }
                        TextField("my-site", text: $name).textFieldStyle(.plain)
                            .font(.jbMono(14.5)).foregroundStyle(KTColor.ink)
                    }
                    SiteFormControls.helper("The subdomain used to serve this site.")
                }
            }

            SiteFormControls.row("PHP Version") {
                SiteFormControls.formDropdown(
                    width: 150,
                    options: availableVersions.map { v in
                        KTDropdownOption(label: "PHP \(v)", active: v == phpVersion) { phpVersion = v }
                    },
                    leading: { SiteFormControls.phpBadge },
                    value: "PHP \(phpVersion)"
                )
            }

            if let detectedKind {
                SiteFormControls.row("Detected") {
                    HStack(spacing: 9) {
                        Image(systemName: SiteVisuals.symbolName(for: detectedKind))
                            .font(.system(size: 13, weight: .medium)).foregroundStyle(KTColor.ink3)
                        Text(SiteVisuals.label(for: detectedKind)).font(.jbMono(14, .regular)).foregroundStyle(KTColor.ink)
                    }
                    .padding(.vertical, 6).padding(.horizontal, 12)
                    .background(Capsule().fill(KTColor.segmentBg))
                }
            }

            SiteFormControls.hairline

            Button { withAnimation(.easeInOut(duration: 0.15)) { advanced.toggle() } } label: {
                HStack(spacing: 11) {
                    Image(systemName: "gearshape").font(.system(size: 15, weight: .regular)).foregroundStyle(KTColor.ink3)
                    Text("Advanced Options").font(KTType.label).foregroundStyle(KTColor.ink)
                    Spacer()
                    Image(systemName: advanced ? "chevron.up" : "chevron.down").font(.system(size: 11, weight: .bold)).foregroundStyle(KTColor.muted)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if advanced {
                VStack(spacing: 14) {
                    SiteFormControls.advancedToggle("Serve over HTTPS", "Issue a trusted local certificate.", $serveHTTPS)
                    SiteFormControls.advancedToggle("Create database", "Provision a matching MySQL database.", $createDatabase)
                }
                .padding(.leading, 29)
            }
        }
    }

    private func pickFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose"
        panel.message = "Select a project folder to serve locally."
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        folder = url
        detectedKind = provisioning.inspect(folder: url, tld: tld).kind
        if name.trimmingCharacters(in: .whitespaces).isEmpty {
            name = url.lastPathComponent
        }
    }
}
