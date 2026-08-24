import KTPluginKit
import SwiftUI

public struct TunnelQRCodeButton: View {
    let url: URL

    @State private var isPresented = false

    public init(url: URL) {
        self.url = url
    }

    public var body: some View {
        Button { isPresented = true } label: {
            Image(systemName: "qrcode")
        }
        .buttonStyle(.borderless)
        .ktTip("Show QR for mobile testing")
        .popover(isPresented: $isPresented) {
            QRCodeView(url: url)
        }
    }
}

public struct QRCodeView: View {
    let url: URL

    private let qrSize: CGFloat = 200

    public init(url: URL) {
        self.url = url
    }

    public var body: some View {
        let image = QRCodeGenerator.image(for: url, size: qrSize)
        let textWidth = max(240, image?.size.width ?? qrSize)

        VStack(spacing: KDSpacing.space3) {
            if let image {
                Image(nsImage: image)
                    .interpolation(.none)
            } else {
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle)
                    .foregroundStyle(Color.KDStatus.warning)
                    .frame(width: qrSize, height: qrSize)
            }

            Text(url.absoluteString)
                .font(KDFont.footnote)
                .textSelection(.enabled)
                .lineLimit(3)
                .multilineTextAlignment(.center)
                .frame(width: textWidth)
        }
        .padding(KDSpacing.space4)
    }
}
