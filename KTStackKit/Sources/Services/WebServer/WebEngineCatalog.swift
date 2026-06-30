import Foundation

// On-demand download pin for the Apache per-site engine. Apache is neither a RuntimeLanguage
// (php/node) nor a ServiceKind, so it has its own tiny catalog. The tarball is the relocatable
// httpd built by scripts/build-apache-relocatable.sh, hosted per-arch on the binaries-v1 release.
public enum WebEngineCatalog {
    public static let apacheVersion = "2.4.68"

    private static let releaseBaseURL =
        URL(string: "https://github.com/KTStackAPP/KTStack/releases/download/binaries-v1")!

    private static let apacheSHA256ByArch: [String: String] = [
        "arm64": "461342f45797d36c5c3af78a9cd721ffcebc004a8be7d495cfec32e822d97989",
        "x86_64": "d5042753ddaa9dc9e06b30aa44ced1396136500457fcdaed3d9c2b1d5510568e",
    ]

    public static var apacheURL: URL {
        releaseBaseURL.appendingPathComponent("apache-\(apacheVersion)-\(RuntimeCatalog.arch).tar.gz")
    }

    public static var apacheSHA256: String {
        apacheSHA256ByArch[RuntimeCatalog.arch] ?? ""
    }
}
