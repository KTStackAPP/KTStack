import KTPlatformContracts
import KTPluginKit
import KTStackCore
import SwiftUI

struct RuntimesScreen: View {
    @ObservedObject var vm: RuntimesViewModel
    @ObservedObject var engines: EngineVersionsViewModel
    let phpConfig: any PHPExtensionManaging & PHPIniEditing & PHPPoolEditing

    @EnvironmentObject var feedback: KTFeedbackCenter

    @State private var category: RuntimesCategory = .php
    @State var filter = ""
    @State var expandedVersion: String?
    @State private var editingIni: VersionRef?
    @State private var editingPool: VersionRef?
    @State private var managingExt: VersionRef?

    private struct VersionRef: Identifiable { let version: String; var id: String {
        version
    } }

    var body: some View {
        GeometryReader { geo in
            let compact = geo.size.width > 0 && (geo.size.width - 180) < 700
            HStack(spacing: 0) {
                KTCategoryRail(sections: railSections, selection: $category, compact: compact)
                    .frame(width: compact ? 44 : 180)
                    .frame(maxHeight: .infinity)
                    .background(KTColor.sidebarBackground)
                    .overlay(alignment: .trailing) {
                        Rectangle().fill(KTColor.sep).frame(width: 0.5)
                    }
                pane
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(KTColor.contentBg)
        .onChange(of: category) { _ in filter = ""; expandedVersion = nil }
        .sheet(item: $editingIni) { PHPIniEditorSheet(version: $0.version, phpConfig: phpConfig) }
        .sheet(item: $editingPool) { PHPPoolEditorSheet(version: $0.version, phpConfig: phpConfig) }
        .sheet(item: $managingExt) { PHPExtensionsSheet(version: $0.version, phpConfig: phpConfig) }
        .ktFeedbackHost(feedback)
    }

    private var pane: some View {
        VStack(alignment: .leading, spacing: 0) {
            paneHeader
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    categoryPane(category)
                }
                .padding(.horizontal, KTSpacing.screenGutter)
                .padding(.top, 16)
                .padding(.bottom, 24)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var paneHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(category.title)
                    .font(KTType.screenTitle).tracking(KTType.screenTitleTracking).foregroundStyle(KTColor.ink)
                Text(category.description)
                    .font(KTType.sub).foregroundStyle(KTColor.muted)
                Spacer(minLength: 8)
            }
            KTSearchField(text: $filter, placeholder: "Filter versions…")
        }
        .padding(.horizontal, KTSpacing.screenGutter)
        .padding(.top, 18)
        .padding(.bottom, 4)
    }

    func editIni(_ version: String) {
        editingIni = VersionRef(version: version)
    }

    func editPool(_ version: String) {
        editingPool = VersionRef(version: version)
    }

    func manageExtensions(_ version: String) {
        managingExt = VersionRef(version: version)
    }

    func toggleInspector(_ version: String) {
        expandedVersion = expandedVersion == version ? nil : version
    }

    func requestUninstall(_ lang: RuntimeLanguage, _ version: String) {
        let prompt = vm.uninstallPrompt(lang, version)
        feedback.confirm(
            title: prompt.title,
            message: prompt.message,
            okLabel: prompt.okLabel,
            danger: true
        ) {
            vm.uninstall(lang, version)
            expandedVersion = nil
            feedback.toast("Removed \(lang.displayName) \(version)")
        }
    }
}
