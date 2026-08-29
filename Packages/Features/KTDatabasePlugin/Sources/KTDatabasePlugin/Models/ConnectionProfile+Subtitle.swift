import Foundation

public extension ConnectionProfile {
    /// Dòng phụ phân biệt kết nối trùng tên (thường "127.0.0.1"): user@host:port · database, hoặc tên file SQLite.
    var subtitle: String {
        if kind == .sqlite, let path = filePath, !path.isEmpty {
            return (path as NSString).lastPathComponent
        }
        let origin = user.isEmpty ? "\(host):\(port)" : "\(user)@\(host):\(port)"
        return database.isEmpty ? origin : "\(origin) · \(database)"
    }
}
