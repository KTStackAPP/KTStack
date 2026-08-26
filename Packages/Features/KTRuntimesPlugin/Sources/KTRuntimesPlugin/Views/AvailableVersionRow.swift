import KTPluginKit
import SwiftUI

struct AvailableVersionRow: View {
    let title: String
    let fraction: Double?
    let progressText: String
    let errorText: String?
    let onInstall: () -> Void
    let onCancel: () -> Void

    init(
        title: String,
        fraction: Double? = nil,
        progressText: String = "",
        errorText: String? = nil,
        onInstall: @escaping () -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.title = title
        self.fraction = fraction
        self.progressText = progressText
        self.errorText = errorText
        self.onInstall = onInstall
        self.onCancel = onCancel
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(title).font(KTType.rowName).foregroundStyle(KTColor.ink2)
            Spacer(minLength: 8)
            trailing
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 18)
        .frame(minHeight: 44)
    }

    @ViewBuilder
    private var trailing: some View {
        if let errorText {
            Text(errorText).font(KTType.caption).foregroundStyle(KTColor.danger).lineLimit(1)
            KTButton(title: "Retry", kind: .secondary, action: onInstall)
        } else if let fraction {
            ProgressView(value: fraction).frame(width: 140)
            Text(progressText).font(KTType.caption).foregroundStyle(KTColor.muted)
                .monospacedDigit().fixedSize()
            Button(action: onCancel) {
                Image(systemName: "xmark.circle").foregroundStyle(KTColor.muted)
                    .frame(width: 28, height: 28).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Cancel download")
        } else {
            Text("SHA-256 verified").font(KTType.caption).foregroundStyle(KTColor.muted)
            KTButton(title: "Install", kind: .primary, action: onInstall)
        }
    }
}

#if DEBUG
    #Preview {
        VStack(spacing: 0) {
            AvailableVersionRow(title: "PHP 8.2", onInstall: {}, onCancel: {})
            AvailableVersionRow(title: "PHP 8.1", fraction: 0.62, progressText: "62% · 40 MB / 64 MB", onInstall: {}, onCancel: {})
            AvailableVersionRow(title: "PHP 7.4", errorText: "Download failed", onInstall: {}, onCancel: {})
        }
        .frame(width: 640)
    }
#endif
