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
    @Published var logTarget: String?

    init(validIDs: Set<String>) {
        let saved = UserDefaults.standard.string(forKey: Self.selectionKey)
        selection = saved.flatMap { validIDs.contains($0) ? $0 : nil } ?? "sites"
    }

    func openLogs(_ sourceID: String?) {
        logTarget = sourceID
        selection = "logs"
    }
}
