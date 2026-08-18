import SwiftUI

public struct KTToast: View {
    public let message: String

    public init(message: String) {
        self.message = message
    }

    public var body: some View {
        HStack(spacing: 9) {
            Image(systemName: "checkmark").font(.system(size: 13, weight: .bold)).foregroundStyle(KTColor.runDot)
            Text(message).font(.jbMono(13.5, .medium)).foregroundStyle(.white)
        }
        .padding(.horizontal, 18).padding(.vertical, 11)
        .background(Capsule().fill(KTColor.ink))
    }
}
