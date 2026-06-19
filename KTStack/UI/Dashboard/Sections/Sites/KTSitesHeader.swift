import SwiftUI
import KTStackKit

struct KTSitesHeader: View {
    let siteCount: Int
    let onScan: () -> Void
    let onImport: () -> Void
    let onNewSite: () -> Void
    let onAddExisting: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text("Sites")
                .font(KTType.screenTitle)
                .tracking(KTType.screenTitleTracking)
                .foregroundStyle(KTColor.ink)
            KTPill(text: "\(siteCount) sites")
            Spacer()
            KTButton(title: "Scan", systemImage: "arrow.triangle.2.circlepath", kind: .secondary, action: onScan)
            KTButton(title: "Import", systemImage: "square.and.arrow.down", kind: .secondary, action: onImport)
            newSiteSplit
        }
    }

    private var newSiteSplit: some View {
        HStack(spacing: 0) {
            Button(action: onNewSite) {
                HStack(spacing: 7) {
                    Image(systemName: "plus").font(.system(size: 13, weight: .bold))
                    Text("New Site").font(.jbMono(13, .semibold))
                }
                .foregroundStyle(.white)
                .padding(.vertical, 9)
                .padding(.horizontal, 15)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .keyboardShortcut("n", modifiers: .command)

            Rectangle().fill(.white.opacity(0.25)).frame(width: 0.5, height: 18)

            Menu {
                Button("New Site…", action: onNewSite)
                Button("Add Existing Folder…", action: onAddExisting)
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 36)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .frame(width: 30)
        }
        .background(KTColor.accentGradient)
        .clipShape(RoundedRectangle(cornerRadius: KTRadius.button, style: .continuous))
    }
}
