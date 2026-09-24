import Foundation

enum ToolTimeout {
    static let launchctl: TimeInterval = 15
    static let processQuery: TimeInterval = 5
    static let codesign: TimeInterval = 30
    static let configTest: TimeInterval = 10
}
