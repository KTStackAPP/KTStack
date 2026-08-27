import KTPlatformContracts
import KTPluginKit

// tint + subtitle là chuyện UI (plugin-local); displayName/symbolName do platform điền qua ServiceState.
extension ServiceID {
    var tint: KTTint {
        switch self {
        case .nginx, .dnsmasq: KTIconTint.globe
        case .phpFpm: KTIconTint.code
        case .mysql, .mariadb, .postgres, .mongodb: KTIconTint.db
        case .redis, .memcached: KTIconTint.cube
        case .mailpit: KTIconTint.mail
        }
    }

    var subtitle: String {
        switch self {
        case .nginx: "Reverse proxy · ports 80, 443"
        case .phpFpm: "FastCGI pools · managed with web server"
        case .dnsmasq: "*.test resolver · port 53 · privileged helper"
        case .mysql: "Database · port 3306"
        case .mariadb: "Database · port 3306 · shares the port with MySQL"
        case .postgres: "Database · port 5432"
        case .redis: "Cache · port 6379"
        case .memcached: "Cache · port 11211"
        case .mongodb: "Document DB · port 27017"
        case .mailpit: "Mail catcher · SMTP 1025 · web 8025"
        }
    }
}
