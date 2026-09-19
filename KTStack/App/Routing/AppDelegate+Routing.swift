import AppKit
import KTDatabasePlugin
import KTDoctorPlugin
import KTServicesPlugin
import KTSitesPlugin

// Ánh xạ route enum của plugin sang selection id sidebar / cửa sổ; giữ id shell trong App, không đưa vào package.
extension AppDelegate {
    // Method chứ không tham chiếu lazy var trong route closure, tránh vòng lazy-init với databaseWindows.
    @MainActor func routeDatabase(_ route: DatabaseRoute) {
        // "Cài trong Runtimes ›" từ trang kết nối: về Dashboard, chọn tab Runtimes.
        if case .runtimes = route {
            navigation.selection = "runtimes"
            AppActivationPolicy.activateRegular()
            AppActivationPolicy.focusExistingWindow(titled: "KTStack Dashboard")
            return
        }
        databaseWindows.handle(route)
    }

    @MainActor func openDatabasePanel() {
        routeDatabase(.workspace(profileID: nil))
    }

    @MainActor func routeServices(_ route: ServicesRoute) {
        switch route {
        case .runtimes: navigation.selection = "runtimes"
        case .settings: navigation.selection = "settings"
        case let .logs(sourceID): navigation.openLogs(sourceID)
        }
    }

    @MainActor func routeSites(_ route: SitesRoute) {
        if case let .logs(sourceID) = route { navigation.openLogs(sourceID) }
    }
}

private extension DoctorRoute {
    var selectionID: String {
        switch self {
        case .services: "services"
        case .settings: "settings"
        case .runtimes: "runtimes"
        }
    }
}

extension AppDelegate {
    @MainActor func routeDoctor(_ route: DoctorRoute) {
        navigation.selection = route.selectionID
    }
}
