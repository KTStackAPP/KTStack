import Foundation

struct DumpServerLimits: Sendable {
    var maxConnectionBytes = 8 * 1024 * 1024
    var maxConnections = 32
    var idleTimeout: TimeInterval = 30
}
