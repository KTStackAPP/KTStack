import Foundation

// Trùng tên với type trong KTStackKit là chủ đích: plugin không bao giờ import Kit.
public enum DoctorStatus: String, Sendable, Equatable, CaseIterable {
    case pass, warn, fail
}

// Mỗi remedy trỏ về một action đã có sẵn trong app.
public enum DoctorRemedyAction: String, Sendable, Equatable {
    case openLoginItems, openServices, openSettings, openRuntimes
}

public struct DoctorCheck: Identifiable, Sendable, Equatable {
    public let id: String
    public let title: String
    public let status: DoctorStatus
    public let detail: String
    public let remedy: String?
    public let action: DoctorRemedyAction?

    public init(
        id: String,
        title: String,
        status: DoctorStatus,
        detail: String,
        remedy: String? = nil,
        action: DoctorRemedyAction? = nil
    ) {
        self.id = id
        self.title = title
        self.status = status
        self.detail = detail
        self.remedy = remedy
        self.action = action
    }
}
