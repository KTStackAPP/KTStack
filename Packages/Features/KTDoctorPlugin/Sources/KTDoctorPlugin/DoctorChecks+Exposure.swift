import Foundation
import KTPlatformContracts
import KTPluginKit
import KTStackCore

extension DoctorChecks {
    static func networkExposure(paths: AppSupportPaths, probes: any DoctorProbing) -> DoctorCheck {
        let title = "Network exposure"
        guard let conf = probes.readFile(paths.nginxConf) else {
            return DoctorCheck(
                id: "exposure", title: title, status: .pass,
                detail: "The web server has not been configured yet, so nothing is listening."
            )
        }
        let beforeServers = conf.components(separatedBy: "server {").first ?? conf
        if beforeServers.contains("deny all;"), beforeServers.contains("allow 127.0.0.1;") {
            return DoctorCheck(
                id: "exposure", title: title, status: .pass,
                detail: "Sites answer only on this Mac; other devices on the network are refused."
            )
        }
        return DoctorCheck(
            id: "exposure", title: title, status: .warn,
            detail: "Sites on this Mac can be opened by other devices on your network.",
            remedy: "If you did not mean to share them, turn off Settings › Sites & Network › Allow devices on your network."
        )
    }
}
