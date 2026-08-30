import AppKit
import KTPluginKit
import SwiftUI

/// Cột trái của tab Database: nhận diện app + ba hành động chính.
struct DatabaseBrandPanel: View {
    let onCreate: () -> Void
    let onImportURL: () -> Void
    let onImportSite: () -> Void
    let onOpenPanel: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: KTSpacing.xl) {
            brand
            Spacer(minLength: KTSpacing.sectionGap)
            actions
        }
        .padding(KTSpacing.sectionGap)
        .frame(width: 220, alignment: .leading)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(KTColor.sidebarBackground)
        .overlay(alignment: .trailing) { Rectangle().fill(KTColor.sep).frame(width: 1) }
    }

    private var brand: some View {
        VStack(alignment: .leading, spacing: KTSpacing.md) {
            if let icon = NSApp.applicationIconImage {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 56, height: 56)
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: KTSpacing.xs) {
                Text("KTStack Database")
                    .font(KTType.screenTitle)
                    .tracking(KTType.screenTitleTracking)
                    .foregroundStyle(KTColor.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(versionText).font(KTType.sub).foregroundStyle(KTColor.muted)
            }
            VStack(alignment: .leading, spacing: KTSpacing.xs) {
                link("GitHub", "https://github.com/KTStackAPP/KTStack")
                link("Release Notes", "https://github.com/KTStackAPP/KTStack/releases")
            }
        }
    }

    private var actions: some View {
        VStack(alignment: .leading, spacing: KTSpacing.sm) {
            KTButton(title: "Create Connection…", systemImage: "plus", kind: .primary, action: onCreate)
                .frame(maxWidth: .infinity, alignment: .leading)
            AddFromExistingMenu(style: .titled, onImportURL: onImportURL, onImportSite: onImportSite)
            KTButton(title: "Open Database Panel", systemImage: "macwindow", action: onOpenPanel)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func link(_ title: String, _ urlString: String) -> some View {
        KTButton(title: title, kind: .link) {
            guard let url = URL(string: urlString) else { return }
            NSWorkspace.shared.open(url)
        }
    }

    private var versionText: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        return version.map { "Version \($0)" } ?? "Version unknown"
    }
}
