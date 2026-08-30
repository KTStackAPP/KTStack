import Foundation

public extension ConnectionProfile {
    /// Dòng phụ phân biệt kết nối trùng tên. Host loopback bị ẩn vì mọi kết nối local đều là
    /// 127.0.0.1, đọc rất rối; badge LOCAL trên hàng đã nói rõ.
    var subtitle: String {
        if kind == .sqlite, let path = filePath, !path.isEmpty {
            return (path as NSString).lastPathComponent
        }
        guard !Self.isLoopback(host) else { return database.isEmpty ? user : database }
        let origin = user.isEmpty ? "\(host):\(port)" : "\(user)@\(host):\(port)"
        return database.isEmpty ? origin : "\(origin) · \(database)"
    }
}
