import KTPluginKit
import SwiftUI

struct ConnectionsPageHeader: View {
    @Binding var search: String
    let onNewConnection: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Kết nối cơ sở dữ liệu")
                    .font(.title2.bold())
                    .foregroundStyle(.primary)
                Text("Chọn một kết nối để duyệt bảng và chạy truy vấn, hoặc tạo kết nối mới.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 10) {
                searchField
                Button(action: onNewConnection) {
                    Label("Kết nối mới", systemImage: "plus")
                        .font(.subheadline.weight(.medium))
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            TextField("Tìm theo tên, host, database…", text: $search)
                .textFieldStyle(.plain)
                .font(.subheadline)
            if !search.isEmpty {
                Button { search = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .frame(maxWidth: 340)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 0.5)
        )
    }
}
