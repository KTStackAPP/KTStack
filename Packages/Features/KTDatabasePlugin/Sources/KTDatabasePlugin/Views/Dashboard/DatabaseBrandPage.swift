import AppKit
import KTPluginKit
import SwiftUI

/// Nội dung tab Database sau khi modal kết nối đóng: nhận diện app + lối vào lại.
struct DatabaseBrandPage: View {
    let onConnections: () -> Void
    let onCreate: () -> Void
    let onOpenPanel: () -> Void

    var body: some View {
        VStack(spacing: KTSpacing.xl) {
            brand
            actions
        }
        .frame(maxWidth: 360)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(KTColor.contentBg)
    }

    private var brand: some View {
        VStack(spacing: KTSpacing.md) {
            if let icon = NSApp.applicationIconImage {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 72, height: 72)
                    .accessibilityHidden(true)
            }
            VStack(spacing: KTSpacing.xs) {
                Text("KTStack Database")
                    .font(KTType.screenTitle)
                    .tracking(KTType.screenTitleTracking)
                    .foregroundStyle(KTColor.ink)
                Text(versionText).font(KTType.sub).foregroundStyle(KTColor.muted)
            }
            HStack(spacing: KTSpacing.md) {
                link("GitHub", "https://github.com/KTStackAPP/KTStack")
                link("Release Notes", "https://github.com/KTStackAPP/KTStack/releases")
            }
        }
    }

    private var actions: some View {
        VStack(spacing: KTSpacing.sm) {
            KTButton(title: "Connections…", systemImage: "cylinder.split.1x2", kind: .primary, action: onConnections)
            KTButton(title: "Create Connection…", systemImage: "plus", action: onCreate)
            KTButton(title: "Open Database Panel", systemImage: "macwindow", action: onOpenPanel)
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
