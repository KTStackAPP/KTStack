import KTPluginKit
import SwiftUI

/// Một cách map trạng thái sang chữ + màu cho cả hàng engine lẫn hàng kết nối đã lưu.
enum ConnectionRowStatus {
    static func color(_ status: ServerStatus) -> Color {
        switch status {
        case .online: KTColor.online
        case .connecting: KTColor.accent
        case .offline: KTColor.muted
        }
    }

    static func engineText(status: ServerStatus, installed: Bool, host: String) -> String {
        switch status {
        case .online: "Running · \(host)"
        case .connecting: "Checking…"
        case .offline: installed ? "Stopped" : "Not installed"
        }
    }

    static func engineLabel(_ kind: DatabaseKind) -> String {
        switch kind {
        case .mysql: "MySQL"
        case .postgres: "PostgreSQL"
        case .sqlite: "SQLite"
        case .mongodb: "MongoDB"
        }
    }

    static func tile(_ kind: DatabaseKind) -> some View {
        KTIconTile(tint: KTEngineTint.of(kind.rawValue), size: 34, radius: 9) {
            Image(systemName: "cylinder.split.1x2").font(.system(size: 14))
        }
    }
}
