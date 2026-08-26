import Foundation

public enum NginxIncludeSaveError: Error, Sendable, Equatable {
    case rejected(String)             // nginx -t fail, đã revert .bak
    case couldNotValidate             // nginx không chạy được, file ĐÃ ghi, không revert
    case reloadFailedReverted(String) // reload fail, đã revert .bak
}

public protocol NginxIncludeEditing: Sendable {
    var defaultInclude: String { get }
    func readInclude() throws -> String
    func saveInclude(_ contents: String) async throws
}
