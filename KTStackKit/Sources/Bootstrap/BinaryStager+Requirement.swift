import Foundation
import KTStackCore

extension BinaryStager {
    static var releaseRequirement: String? {
        #if DEBUG
            return nil
        #else
            return HelperIdentity.teamRequirement
        #endif
    }

    static func codesignArguments(for url: URL, requirement: String?) -> [String] {
        var arguments = ["--verify", "--strict"]
        if let requirement { arguments += ["-R", requirement] }
        return arguments + [url.path]
    }
}
