import KTPluginKit
import KTStackKit
import SwiftUI

// Màu trạng thái là chuyện UI: Kit không được kéo token từ KTPluginKit.
extension ServiceStatus {
    var color: Color {
        switch self {
        case .running: .KDStatus.running
        case .stopped: .KDStatus.stopped
        case .starting: .KDStatus.starting
        case .stopping: .KDStatus.starting
        case .warning: .KDStatus.warning
        case .error: .KDStatus.error
        case .info: .KDStatus.info
        }
    }
}
