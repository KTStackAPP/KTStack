import Foundation

public enum HelperIdentity {
    public static let machServiceName = "com.kdwarm.helper"
    public static let helperBundleID  = "com.kdwarm.helper"
    public static let appBundleID     = "com.kdwarm.app"

   
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
