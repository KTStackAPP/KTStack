import Foundation
import KTStackCore

enum HelperSignatureValidator {
    static func isTrustedClient(_ connection: NSXPCConnection) -> Bool {
        guard HelperIdentity.hasSigningIdentity else { return false }
        connection.setCodeSigningRequirement(HelperIdentity.clientRequirement)
        return true
    }
}
