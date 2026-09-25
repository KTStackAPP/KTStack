import Foundation

public enum ServerActionQueuePolicy {
    public static let defaultsKey = "KTStack.queueServerActions"

    public static func isEnabled(defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: defaultsKey) as? Bool ?? true
    }
}
