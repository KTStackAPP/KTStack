import Foundation

// On-demand download pin for the Apache per-site engine. Apache is neither a RuntimeLanguage
// (php/node) nor a ServiceKind, so it has its own tiny catalog. The tarball is the relocatable
// httpd built by scripts/build-apache-relocatable.sh, hosted per-arch on the binaries-v1 release.
public enum WebEngineCatalog {
    public static let apacheVersion = "2.4.68"

    private static let releaseBaseURL =
        URL(string: "https://github.com/KTStackAPP/KTStack/releases/download/binaries-v1")!

    private static let apacheSHA256ByArch: [String: String] = [
        "arm64": "fd56278cec77b49be49e1b47637365a8655fc84bd01d61d4fe87e4dd448a642b",
        "x86_64": "7141bd26b9f47f6ad4e03026f67990db86efffee40aefd9e39ae1ed430acb76c",
    ]

    public static var apacheURL: URL {
        releaseBaseURL.appendingPathComponent("apache-\(apacheVersion)-\(RuntimeCatalog.arch).tar.gz")
    }

    public static var apacheSHA256: String {
        apacheSHA256ByArch[RuntimeCatalog.arch] ?? ""
    }
}
