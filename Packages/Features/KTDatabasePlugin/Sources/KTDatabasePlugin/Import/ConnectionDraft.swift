import Foundation

/// Kết nối chưa lưu, dựng từ DSN hoặc file .env, đổ sẵn vào AddConnectionSheet.
struct ConnectionDraft: Sendable, Equatable {
    let profile: ConnectionProfile
    let password: String?
}

extension DatabaseKind {
    var defaultPort: Int {
        switch self {
        case .mysql: 3306
        case .postgres: 5432
        case .mongodb: 27017
        case .sqlite: 0
        }
    }
}
