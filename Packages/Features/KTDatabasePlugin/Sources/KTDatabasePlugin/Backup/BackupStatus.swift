import Foundation

public enum BackupStatus: Equatable {
    case idle
    case running(String)
    case done(String)
    case failed(String)
}
