import Foundation
import KTPlatformContracts

public enum DatabaseRoute: Sendable, Equatable {
    case documentBrowser
    case workspace(profileID: UUID?)
    case closeDocumentBrowser
    case closeWorkspace
    case runtimes(DatabaseEngine)
    #if DEBUG
        case sqlDrafts
    #endif
}
