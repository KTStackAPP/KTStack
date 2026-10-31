import Foundation

public enum SiteGroupError: LocalizedError, Equatable {
    case tooLong

    public var errorDescription: String? {
        switch self {
        case .tooLong: "Group names can be up to \(SiteGroupName.maxLength) characters."
        }
    }
}

public enum SiteGroupName {
    public static let maxLength = 40

    // Gọn khoảng trắng; nil khi rỗng để site về "No Group".
    public static func normalize(_ raw: String) throws -> String? {
        let collapsed = raw.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        guard !collapsed.isEmpty else { return nil }
        guard collapsed.count <= maxLength else { throw SiteGroupError.tooLong }
        return collapsed
    }
}
