public enum DatabaseRoute: Sendable, Equatable {
    case sqlEditor
    case documentBrowser
    case closeSQLEditor
    case closeDocumentBrowser
    #if DEBUG
        case sqlDrafts
    #endif
}
