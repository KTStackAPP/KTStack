import Foundation
import KTStackCore

struct ShellShimWriter {
    let paths: AppSupportPaths

    var helperPath: String {
        paths.shimBinDir.appendingPathComponent("ktstack-resolve").path
    }

    var shimDir: String {
        paths.shimBinDir.path
    }

    private let phpConfigIsolation = """
    __ktphp_dir="${target%/bin/*}"
    __ktphp_ver="${__ktphp_dir##*/}"
    __ktphp_root="${__ktphp_dir%/runtimes/php/*}"
    [ -d "$__ktphp_root/config/php/$__ktphp_ver" ] && export PHPRC="$__ktphp_root/config/php/$__ktphp_ver"
    [ -d "$__ktphp_dir/conf.d" ] && export PHP_INI_SCAN_DIR="$__ktphp_dir/conf.d"
    if [ -d "$__ktphp_dir/modules/imagick-magick/coders" ]; then
        export MAGICK_HOME="$__ktphp_dir/modules/imagick-magick"
        export MAGICK_CODER_MODULE_PATH="$__ktphp_dir/modules/imagick-magick/coders"
        export MAGICK_CODER_FILTER_PATH="$__ktphp_dir/modules/imagick-magick/filters"
        export MAGICK_CONFIGURE_PATH="$__ktphp_dir/modules/imagick-magick/config"
    fi
    """

    func directBinaryShim(tool: String) -> String {
        let isolation = tool == "php" ? "\n" + phpConfigIsolation : ""
        return """
        #!/bin/sh
        system_path="$(printf '%s' "$PATH" | tr ':' '\\n' | grep -vxF "\(shimDir)" | paste -sd ':' -)"
        if target="$("\(helperPath)" "\(tool)" "$PWD" 2>/dev/null)"; then
            export PATH="${target%/*}:$system_path"\(isolation)
            exec "$target" "$@"
        fi
        if fallback="$(PATH="$system_path" command -v \(tool) 2>/dev/null)"; then
            exec "$fallback" "$@"
        fi
        echo "ktstack: \(tool) is not enabled or installed — open KTStack to manage tools" >&2
        exit 127
        """
    }

    func pharShim(name: String, phar: String) -> String {
        """
        #!/bin/sh
        system_path="$(printf '%s' "$PATH" | tr ':' '\\n' | grep -vxF "\(shimDir)" | paste -sd ':' -)"
        if target="$("\(helperPath)" "\(name)" "$PWD" 2>/dev/null)"; then
            export PATH="${target%/*}:$system_path"
            \(phpConfigIsolation)
            exec "$target" "\(phar)" "$@"
        fi
        if fallback="$(PATH="$system_path" command -v \(name) 2>/dev/null)"; then
            exec "$fallback" "$@"
        fi
        echo "ktstack: \(name) is not enabled or installed — open KTStack to manage tools" >&2
        exit 127
        """
    }

    var shims: [String: String] {
        var map: [String: String] = [:]
        for tool in ShellToolCatalog.tools {
            if tool.id == "composer" {
                map[tool.command] = pharShim(name: tool.id, phar: paths.composerPhar.path)
            } else if tool.id == "wp" {
                map[tool.command] = pharShim(name: tool.id, phar: paths.wpCliPhar.path)
            } else {
                map[tool.command] = directBinaryShim(tool: tool.command)
            }
        }
        return map
    }

    func writeShims() throws {
        let fm = FileManager.default
        for (name, body) in shims {
            if name == "kt" {
                let ktDest = paths.shimBinDir.appendingPathComponent("kt")
                if fm.isExecutableFile(atPath: ktDest.path) {
                    continue
                }
            }
            let url = paths.shimBinDir.appendingPathComponent(name)
            try (body + "\n").data(using: .utf8)!.write(to: url, options: .atomic)
            try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        }
    }
}
