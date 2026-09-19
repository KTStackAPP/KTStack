import AppKit
import CoreSpotlight
import KTStackCore
import UniformTypeIdentifiers

// ktstack:// deep link + CoreSpotlight fallback. Route chỉ đi qua AppURLRoute → routeDatabase (xem CLAUDE.md Invariants).
extension AppDelegate {
    static let spotlightDatabaseID = "database-workspace"
    static let openDatabaseActivityType = "com.ktstack.open-database"

    func application(_: NSApplication, open urls: [URL]) {
        MainActor.assumeIsolated {
            for url in urls {
                if isReadyForURLs { handle(url: url) } else { pendingURLs.append(url) }
            }
        }
    }

    func application(
        _: NSApplication,
        continue userActivity: NSUserActivity,
        restorationHandler _: @escaping ([any NSUserActivityRestoring]) -> Void
    ) -> Bool {
        MainActor.assumeIsolated {
            switch userActivity.activityType {
            case CSSearchableItemActionType:
                let id = userActivity.userInfo?[CSSearchableItemActivityIdentifier] as? String
                guard id == Self.spotlightDatabaseID else { return false }
            case Self.openDatabaseActivityType:
                break
            default:
                return false
            }
            route(.database(profileID: nil))
            return true
        }
    }

    @MainActor
    func handle(url: URL) {
        route(AppURLRoute(url))
    }

    @MainActor
    private func route(_ appRoute: AppURLRoute) {
        switch appRoute {
        case let .database(profileID):
            routeDatabase(.workspace(profileID: profileID))
        case .unknown:
            NSLog("KTStack: ignored unknown deep link route")
        }
    }

    // Idempotent: index lại mỗi launch để LaunchServices/Spotlight thấy mục dù cache cũ.
    @MainActor
    func indexDatabaseSpotlightItem() {
        let attributes = CSSearchableItemAttributeSet(contentType: .application)
        attributes.title = "KTStack Database"
        attributes.displayName = "KTStack Database"
        attributes.contentDescription = "Open the KTStack database workspace"
        attributes.keywords = ["database", "sql", "mysql", "postgres", "ktstack"]
        let item = CSSearchableItem(
            uniqueIdentifier: Self.spotlightDatabaseID,
            domainIdentifier: "com.ktstack.app",
            attributeSet: attributes
        )
        CSSearchableIndex.default().indexSearchableItems([item]) { error in
            if let error { NSLog("KTStack: Spotlight index failed: \(error.localizedDescription)") }
        }
    }
}
