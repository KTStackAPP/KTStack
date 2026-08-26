import Foundation

// Đề xuất lệnh khởi động Node từ package.json (dev/start); chỉ UI dùng, không đụng platform.
enum NodeStartCommand {
    static func suggested(at folder: URL) -> String? {
        let packageJSON = folder.appendingPathComponent("package.json")
        guard let data = try? Data(contentsOf: packageJSON),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let scripts = root["scripts"] as? [String: Any] else { return nil }
        if scripts["dev"] != nil { return "npm run dev" }
        if scripts["start"] != nil { return "npm start" }
        return nil
    }
}
