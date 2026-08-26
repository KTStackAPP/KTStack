import KTPlatformContracts
import KTPluginKit

// Display plugin-local cho 4 engine. rawValue trùng thư mục runtime nên rowNote path giữ nguyên.
extension ServiceEngine {
    var displayName: String {
        switch self {
        case .mysql: "MySQL"
        case .postgres: "PostgreSQL"
        case .redis: "Redis"
        case .mongodb: "MongoDB"
        }
    }

    var symbolName: String {
        switch self {
        case .mysql: "cylinder.split.1x2"
        case .postgres: "cylinder.split.1x2.fill"
        case .redis: "bolt.fill"
        case .mongodb: "leaf.fill"
        }
    }

    var tint: KTTint {
        switch self {
        case .mysql, .postgres, .mongodb: KTIconTint.db
        case .redis: KTIconTint.cube
        }
    }
}
