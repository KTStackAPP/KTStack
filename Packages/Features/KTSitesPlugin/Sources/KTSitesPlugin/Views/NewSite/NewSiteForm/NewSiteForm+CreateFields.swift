import KTPlatformContracts
import KTPluginKit
import SwiftUI

extension NewSiteForm {
    var createForm: some View {
        VStack(alignment: .leading, spacing: 18) {
            SiteFormControls.row("Site Name", topAligned: true) {
                VStack(alignment: .leading, spacing: 7) {
                    SiteFormControls.fieldBox {
                        SiteFormControls.smallTile(KTIconTint.code) { KTSiteGlyph(kind: .code, size: 15, color: KTIconTint.code.fg) }
                        TextField("my-site", text: $name).textFieldStyle(.plain).font(.jbMono(14.5)).foregroundStyle(KTColor.ink)
                    }
                    SiteFormControls.helper("This will be used as the folder name and site label.")
                }
            }
            SiteFormControls.row("Type") {
                SiteFormControls.formDropdown(
                    width: 220,
                    options: NewSiteKind.allCases.map { k in
                        KTDropdownOption(label: kindLabel(k), active: k == kind) { kind = k }
                    },
                    leading: { KTBadge(text: kindBadge(kind), tint: kindTint(kind)) },
                    value: kindLabel(kind)
                )
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
            if kind != .empty { adminPasswordSection }

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

    func kindLabel(_ k: NewSiteKind) -> String {
        k.label
    }

    func kindBadge(_ k: NewSiteKind) -> String {
        switch k {
        case .wordpress: "WP"
        case .laravel: "LV"
        case .empty: "PHP"
        }
    }

    func kindTint(_ k: NewSiteKind) -> KTTint {
        switch k {
        case .wordpress: KTIconTint.code
        case .laravel: KTTint(fg: Color(hex: 0xFF2D20), bg: Color(hex: 0xFFE9E7))
        case .empty: KTIconTint.php
        }
    }
}
