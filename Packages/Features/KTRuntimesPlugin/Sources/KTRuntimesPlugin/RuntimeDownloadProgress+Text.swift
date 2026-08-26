import Foundation
import KTPlatformContracts

extension RuntimeDownloadProgress {
    /// "62% · 40 MB / 64 MB"; chưa biết tổng thì "Starting…".
    var progressText: String {
        guard total > 0 else { return "Starting…" }
        let percent = Int(fraction * 100)
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useMB]
        let received = formatter.string(fromByteCount: received)
        let total = formatter.string(fromByteCount: total)
        return "\(percent)% · \(received) / \(total)"
    }
}
