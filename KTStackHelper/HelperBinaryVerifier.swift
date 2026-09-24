import Foundation
import KTStackCore
import Security

enum HelperBinaryVerifier {
    static func isTrusted(_ url: URL) -> Bool {
        guard let requirementText = HelperIdentity.teamRequirement else {
            #if DEBUG
                return true
            #else
                return false
            #endif
        }
        var code: SecStaticCode?
        var requirement: SecRequirement?
        guard SecStaticCodeCreateWithPath(url as CFURL, [], &code) == errSecSuccess, let code,
              SecRequirementCreateWithString(requirementText as CFString, [], &requirement) == errSecSuccess,
              let requirement else { return false }
        let flags = SecCSFlags(rawValue: kSecCSStrictValidate | kSecCSCheckAllArchitectures)
        return SecStaticCodeCheckValidity(code, flags, requirement) == errSecSuccess
    }
}
