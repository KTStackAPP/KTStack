import KTPluginKit
import SwiftUI

/// Trang chưa nối (mockup bản 1): glyph, tiêu đề, nút nối profile đang chọn + nút kết nối mới.
struct ConnectionLandingView: View {
    let selectedProfile: ConnectionProfile?
    let isConnecting: Bool
    let onConnect: () -> Void
    let onNewConnection: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "cylinder.split.1x2")
                .font(.system(size: 46, weight: .light))
                .foregroundStyle(KTEditorTheme.label3)
            VStack(spacing: 6) {
                Text("Chọn một kết nối để bắt đầu")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(KTEditorTheme.label)
                Text("Chọn một kết nối ở thanh bên, hoặc tạo kết nối mới để duyệt bảng và chạy truy vấn.")
                    .font(.system(size: 12))
                    .foregroundStyle(KTEditorTheme.label2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)
            }
            HStack(spacing: 10) {
                if let selectedProfile {
                    Button(action: onConnect) {
                        HStack(spacing: 6) {
                            if isConnecting { ProgressView().controlSize(.small) }
                            Text("Kết nối \(selectedProfile.name)")
                        }
                        .frame(minWidth: 120)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isConnecting)
                }
                Button(action: onNewConnection) {
                    Text("＋ Kết nối mới")
                }
                .buttonStyle(.bordered)
            }
            Text("⏎ Kết nối · ⌘0 Ẩn/hiện thanh bên · ⌘⇧D Mở Database")
                .font(.system(size: 11))
                .foregroundStyle(KTEditorTheme.label3)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(KTEditorTheme.content)
    }
}
