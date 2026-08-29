import Foundation

public enum DatabaseRoute: Sendable, Equatable {
    case documentBrowser
    case workspace(profileID: UUID?)
    case closeDocumentBrowser
    case closeWorkspace
    #if DEBUG
        case sqlDrafts
    #endif
}
