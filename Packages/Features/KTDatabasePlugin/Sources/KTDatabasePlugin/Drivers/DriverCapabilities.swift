import Foundation

// Khả năng editor mà driver quảng bá; UI bật tính năng theo đây, không theo tên engine.
public struct DriverCapabilities: Sendable, Equatable {
    public var canBrowsePaged: Bool
    public var canEditRows: Bool
    public var canEditSchema: Bool
    public var canCancelQueries: Bool

    public init(
        canBrowsePaged: Bool = true,
        canEditRows: Bool = true,
        canEditSchema: Bool = true,
        canCancelQueries: Bool = true
    ) {
        self.canBrowsePaged = canBrowsePaged
        self.canEditRows = canEditRows
        self.canEditSchema = canEditSchema
        self.canCancelQueries = canCancelQueries
    }

    // Chưa kết nối: không quảng bá khả năng nào.
    public static let none = DriverCapabilities(
        canBrowsePaged: false,
        canEditRows: false,
        canEditSchema: false,
        canCancelQueries: false
    )
}
