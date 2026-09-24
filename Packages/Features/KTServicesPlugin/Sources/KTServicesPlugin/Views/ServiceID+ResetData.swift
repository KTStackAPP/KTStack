import KTPlatformContracts

extension ServiceID {
    var keepsData: Bool {
        switch self {
        case .mysql, .mariadb, .postgres, .redis, .mongodb: true
        default: false
        }
    }

    static func resetDataMessage(_ name: String) -> String {
        "This stops \(name) and moves the active version's data to a .removed folder. "
            + "The next start creates an empty datastore. You can restore the old data from Runtimes."
    }
}
