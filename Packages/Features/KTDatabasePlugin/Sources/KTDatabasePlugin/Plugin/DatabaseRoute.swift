import Foundation

public enum DatabaseRoute: Sendable, Equatable {
    case sqlEditor
    case documentBrowser
    case workspace(profileID: UUID?)
    case closeSQLEditor
    case closeDocumentBrowser
    case closeWorkspace
    #if DEBUG
        case sqlDrafts
    #endif
}
