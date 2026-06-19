import Foundation

public enum HelperIdentity {
    public static let machServiceName = "com.ktstack.helper"
    public static let helperBundleID  = "com.ktstack.helper"
    public static let appBundleID     = "com.ktstack.app"

   
    public static let teamID = ""

    
    public static var hasSigningIdentity: Bool { !teamID.isEmpty }

    public static var clientRequirement: String { requirement(for: appBundleID) }

   
    public static var helperRequirement: String { requirement(for: helperBundleID) }

    private static func requirement(for identifier: String) -> String {
        teamID.isEmpty
            ? "identifier \"\(identifier)\""
            : "anchor apple generic and identifier \"\(identifier)\" "
              + "and certificate leaf[subject.OU] = \"\(teamID)\""
    }
}
