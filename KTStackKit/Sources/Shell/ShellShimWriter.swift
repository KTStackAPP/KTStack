import Foundation

struct ShellShimWriter {
    let paths: AppSupportPaths

    var helperPath: String { paths.shimBinDir.appendingPathComponent("ktstack-resolve").path }

    func directBinaryShim(lang: String) -> String {
        """
        #!/bin/sh
        export PATH=/usr/bin:/bin
        target="$("\(helperPath)" \(lang) "$PWD")" || { echo "ktstack: \(lang) is not installed — open KTStack to add a runtime" >&2; exit 127; }
        exec "$target" "$@"
        """
    }

    func pharShim(name: String, phar: String) -> String {
        """
        #!/bin/sh
        export PATH=/usr/bin:/bin
        phar="\(phar)"
        [ -f "$phar" ] || { echo "ktstack: \(name) is not provisioned — open KTStack to install it" >&2; exit 127; }
        target="$("\(helperPath)" php "$PWD")" || { echo "ktstack: php is not installed" >&2; exit 127; }
        exec "$target" "$phar" "$@"
        """
    }

    var shims: [String: String] {
        [
            "php": directBinaryShim(lang: "php"),
            "node": directBinaryShim(lang: "node"),
            "composer": pharShim(name: "composer", phar: paths.composerPhar.path),
            "wp": pharShim(name: "wp", phar: paths.wpCliPhar.path),
        ]
    }

    func writeShims() throws {
        let fm = FileManager.default
        for (name, body) in shims {
            let url = paths.shimBinDir.appendingPathComponent(name)
            try (body + "\n").data(using: .utf8)!.write(to: url, options: .atomic)
            try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        }
    }
}
