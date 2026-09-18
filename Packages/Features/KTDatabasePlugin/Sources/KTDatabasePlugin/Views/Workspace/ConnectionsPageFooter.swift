import SwiftUI

struct ConnectionsPageFooter: View {
    var body: some View {
        HStack(spacing: 10) {
            Text("⏎ Mở · ⌘0 Ẩn/hiện thanh bên · ⌘T Tab mới")
                .font(.footnote)
                .foregroundStyle(.tertiary)
            Spacer(minLength: 0)
            if let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String {
                Text("KTStack \(version)")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.top, 4)
    }
}
