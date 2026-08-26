import KTPlatformContracts
import KTPluginKit
import KTStackCore
import SwiftUI

struct RuntimeInspectorView: View {
    @StateObject private var model: RuntimeInspectorModel
    let phpConfig: any PHPExtensionManaging & PHPIniEditing & PHPPoolEditing
    let onEditIni: () -> Void
    let onEditPool: () -> Void
    let onManageExtensions: () -> Void
    let onUninstall: () -> Void

    init(
        version: String,
        language: RuntimeLanguage,
        sites: [String],
        phpConfig: any PHPExtensionManaging & PHPIniEditing & PHPPoolEditing,
        onEditIni: @escaping () -> Void,
        onEditPool: @escaping () -> Void,
        onManageExtensions: @escaping () -> Void,
        onUninstall: @escaping () -> Void
    ) {
        _model = StateObject(wrappedValue: RuntimeInspectorModel(
            version: version, language: language, sites: sites, phpConfig: phpConfig
        ))
        self.phpConfig = phpConfig
        self.onEditIni = onEditIni
        self.onEditPool = onEditPool
        self.onManageExtensions = onManageExtensions
        self.onUninstall = onUninstall
    }

    var body: some View {
        Group {
            if model.language == .php {
                HStack(alignment: .top, spacing: 28) {
                    configColumn.frame(maxWidth: .infinity, alignment: .leading)
                    sitesColumn.frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Sites run their own Node server; this version is for terminals.")
                        .font(KTType.sub).foregroundStyle(KTColor.muted)
                    dangerZone
                }
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(KTColor.contentBg)
        .overlay(alignment: .leading) { Rectangle().fill(KTColor.accent).frame(width: 3) }
        .task { await model.load() }
    }

    // MARK: Configuration

    private var configColumn: some View {
        VStack(alignment: .leading, spacing: 12) {
            columnTitle("Configuration")
            configRow(label: "php.ini", detail: nil, actionTitle: "Edit…", action: onEditIni)
            configRow(label: "PHP-FPM pool", detail: model.poolSummary, actionTitle: "Edit…", action: onEditPool)
            configRow(label: "Extensions", detail: extensionDetail, actionTitle: "Manage…", action: onManageExtensions)
            XdebugToggleView(version: model.version, phpConfig: phpConfig)
        }
    }

    private var extensionDetail: String? {
        model.optionalExtensionCount.map { "\($0) optional installed" }
    }

    private func configRow(label: String, detail: String?, actionTitle: String, action: @escaping () -> Void) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text(label).font(KTType.body).foregroundStyle(KTColor.ink)
                if let detail {
                    Text(detail).font(KTType.caption).foregroundStyle(KTColor.muted)
                }
            }
            Spacer(minLength: 8)
            KTButton(title: actionTitle, kind: .secondary, action: action)
        }
    }

    // MARK: Sites + danger zone

    private var sitesColumn: some View {
        VStack(alignment: .leading, spacing: 12) {
            columnTitle("Used by \(model.sites.count) \(model.sites.count == 1 ? "site" : "sites")")
            if model.sites.isEmpty {
                Text("No sites use this version").font(KTType.sub).foregroundStyle(KTColor.muted)
            } else {
                siteChips
            }
            dangerZone
        }
    }

    private var siteChips: some View {
        let shown = Array(model.sites.prefix(8))
        let overflow = model.sites.count - shown.count
        return LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 6)], alignment: .leading, spacing: 6) {
            ForEach(shown, id: \.self) { KTPill(text: $0) }
            if overflow > 0 {
                Text("+\(overflow) more").font(KTType.caption).foregroundStyle(KTColor.muted)
            }
        }
    }

    private var dangerZone: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Danger zone").font(.jbMono(11, .bold)).tracking(0.6).foregroundStyle(KTColor.faint)
            KTButton(title: "Uninstall…", systemImage: "trash", kind: .danger, action: onUninstall)
        }
        .padding(.top, 4)
    }

    private func columnTitle(_ text: String) -> some View {
        Text(text).font(.jbMono(12, .semibold)).foregroundStyle(KTColor.ink2)
    }
}
