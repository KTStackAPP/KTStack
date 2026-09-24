import Foundation

public enum FrontAccessPolicy {
    public static let defaultsKey = "KTStack.allowLANAccess"

    public static func allowsLAN(defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: defaultsKey)
    }

    static func httpRules(allowLAN: Bool) -> String {
        allowLAN ? "" : "allow 127.0.0.1;\n    allow ::1;\n    deny all;\n    "
    }

    static let backendRealIP = "\n        set_real_ip_from 127.0.0.1;\n        real_ip_header X-Real-IP;"

    static let tunnelClientIP = "\n    allow all;\n    set_real_ip_from 127.0.0.1;\n    set_real_ip_from ::1;\n    real_ip_header CF-Connecting-IP;"
}
