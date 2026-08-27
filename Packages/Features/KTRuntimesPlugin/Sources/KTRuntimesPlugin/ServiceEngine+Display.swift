import KTPlatformContracts
import KTPluginKit

/// Display plugin-local cho 6 DB/cache engine. rawValue trùng thư mục runtime nên rowNote path giữ nguyên.
extension ServiceEngine {
    var displayName: String {
        switch self {
        case .mysql: "MySQL"
        case .mariadb: "MariaDB"
        case .postgres: "PostgreSQL"
        case .redis: "Redis"
        case .memcached: "Memcached"
        case .mongodb: "MongoDB"
        }
    }

    var symbolName: String {
        switch self {
        case .mysql: "cylinder.split.1x2"
        case .mariadb: "cylinder.split.1x2"
        case .postgres: "cylinder.split.1x2.fill"
        case .redis: "bolt.fill"
        case .memcached: "memorychip"
        case .mongodb: "leaf.fill"
        }
    }

    var tint: KTTint {
        switch self {
        case .mysql, .mariadb, .postgres, .mongodb: KTIconTint.db
        case .redis, .memcached: KTIconTint.cube
        }
    }
}
