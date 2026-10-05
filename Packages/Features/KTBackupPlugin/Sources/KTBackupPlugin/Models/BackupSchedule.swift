import Foundation

public struct BackupSchedule: Codable, Equatable, Sendable {
    public enum Frequency: String, Codable, Sendable, CaseIterable {
        case daily, weekly
    }

    public var frequency: Frequency
    public var weekday: Int
    public var hour: Int
    public var minute: Int

    public init(frequency: Frequency, weekday: Int = 1, hour: Int, minute: Int) {
        self.frequency = frequency
        self.weekday = min(max(weekday, 1), 7)
        self.hour = min(max(hour, 0), 23)
        self.minute = min(max(minute, 0), 59)
    }

    public static let nightly = BackupSchedule(frequency: .daily, hour: 2, minute: 0)

    var matchingComponents: DateComponents {
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        components.second = 0
        if frequency == .weekly {
            components.weekday = weekday
        }
        return components
    }
}
