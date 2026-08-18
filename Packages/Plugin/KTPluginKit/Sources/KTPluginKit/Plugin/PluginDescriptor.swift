import Foundation

// id là persistence string cho sidebar selection: đóng băng từ M03, đổi là mất selection đã lưu.
public struct PluginDescriptor: Sendable, Hashable {
    public let id: String
    public let title: String
    public let systemImage: String

    public init(id: String, title: String, systemImage: String) {
        self.id = id
        self.title = title
        self.systemImage = systemImage
    }
}
