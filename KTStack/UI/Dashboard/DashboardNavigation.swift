import Combine
import Foundation

@MainActor
final class DashboardNavigation: ObservableObject {
    static let selectionKey = "KTStack.dashboardSelection"

    // "KTStack.dashboardSelection": persistence string frozen như mọi KTStack.* key khác.
    @Published var selection: String {
        didSet { UserDefaults.standard.set(selection, forKey: Self.selectionKey) }
    }

    @Published var activeItem: String?

    // AppDelegate nối vào KTLogsPlugin.show(sourceID:). Gọi trước khi đổi selection để
    // pendingTarget đặt xong trước khi activation của tab Logs chạy.
    var openLogsHandler: ((String?) -> Void)?

    init(validIDs: Set<String>) {
        let saved = UserDefaults.standard.string(forKey: Self.selectionKey)
        selection = saved.flatMap { validIDs.contains($0) ? $0 : nil } ?? "sites"
    }

    func openLogs(_ sourceID: String?) {
        openLogsHandler?(sourceID)
        selection = "logs"
    }
}
