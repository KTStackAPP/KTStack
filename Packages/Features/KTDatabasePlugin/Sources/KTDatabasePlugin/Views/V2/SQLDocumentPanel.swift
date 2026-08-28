import AppKit
import UniformTypeIdentifiers

// Mở/lưu file .sql qua NSOpenPanel/NSSavePanel; chỉ đọc/ghi văn bản, không đụng thông tin kết nối.
enum SQLDocumentPanel {
    static var sqlType: UTType { UTType(filenameExtension: "sql") ?? .plainText }

    static func open() -> (name: String, text: String)? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [sqlType, .plainText]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url,
              let text = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        return (url.lastPathComponent, text)
    }

    static func save(text: String, suggestedName: String = "query.sql") {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [sqlType]
        panel.nameFieldStringValue = suggestedName
        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? text.write(to: url, atomically: true, encoding: .utf8)
    }
}
