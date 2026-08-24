#!/usr/bin/env bash
# Package boundary gate: SPM manifest is the primary fence, this is the backstop.
# Enforces docs/architecture/dependency-rules.md (design doc section 4) so a
# forbidden dependency fails the gate before lint instead of at some later merge.
set -euo pipefail
cd "$(dirname "$0")/.."

VIOLATIONS=0

report() {
    printf '  ✗ %s\n' "$1"
    VIOLATIONS=$((VIOLATIONS + 1))
}

# Local package path deps allowed per package (own external SPM deps are unrestricted).
allowed_pkg_deps() {
    case "$1" in
        Packages/Core/*) echo "" ;;
        Packages/Contracts/*) echo "KTStackCore" ;;
        Packages/Plugin/*) echo "KTStackCore" ;;
        Packages/Features/*) echo "KTStackCore KTPlatformContracts KTPluginKit" ;;
        *) echo "" ;;
    esac
}

# --- (a) Manifest layer: cross-package path deps match the rule table ---
while IFS= read -r manifest; do
    pkg_dir="${manifest%/Package.swift}"
    tier_dir=$(printf '%s' "$pkg_dir" | sed -E 's#(Packages/[^/]+)/.*#\1#')
    allowed=" $(allowed_pkg_deps "$tier_dir/x") "
    while IFS= read -r dep_path; do
        [ -z "$dep_path" ] && continue
        dep_name=$(basename "$dep_path")
        case "$allowed" in
            *" $dep_name "*) ;;
            *) report "$manifest depends on $dep_name (not allowed for ${tier_dir#Packages/})" ;;
        esac
    done < <(grep -oE '\.package\(path: *"[^"]+"' "$manifest" | sed -E 's/.*"([^"]+)".*/\1/')
done < <(find Packages -mindepth 3 -maxdepth 3 -name Package.swift)

# --- (b) Import layer: forbidden imports in source (^import only) ---
# args: <label> <path glob root> <extended regex of forbidden module names>
# Matches `import X`, multi-space `import  X`, and scoped `import class X.Y`.
check_imports() {
    local label="$1" root="$2" forbidden="$3"
    [ -d "$root" ] || return 0
    local hits
    hits=$(grep -rnE "^import[[:space:]]+([[:alnum:]_]+[[:space:]]+)?($forbidden)([[:space:].]|$)" "$root" --include='*.swift' 2>/dev/null || true)
    [ -z "$hits" ] && return 0
    while IFS= read -r line; do
        report "$label: $line"
    done <<< "$hits"
}

for src in Packages/Core/*/Sources; do
    [ -d "$src" ] || continue
    # Core is Foundation + minimal Apple system framework only; flag anything else.
    hits=$(grep -rnE '^import[[:space:]]' "$src" --include='*.swift' 2>/dev/null \
        | grep -vE ':import[[:space:]]+([[:alnum:]_]+[[:space:]]+)?(Foundation|Security)([[:space:].]|$)' || true)
    if [ -n "$hits" ]; then
        while IFS= read -r line; do
            report "Core may import only Foundation/Security: $src $line"
        done <<< "$hits"
    fi
done

check_imports "Contracts" "Packages/Contracts" "SwiftUI|AppKit|KTStackKit|KTPluginKit"
check_imports "Plugin"    "Packages/Plugin"    "KTStackKit|KTPlatformContracts"
check_imports "KTStackKit" "KTStackKit/Sources" "KTPluginKit|MySQLNIO|PostgresNIO|GRDB|MongoKitten|MongoCore|NIOCore|NIOPosix|NIOSSL|Logging"

# Feature packages (M04+): no platform implementation, no sibling feature.
if compgen -G "Packages/Features/*/Sources" >/dev/null 2>&1; then
    feature_mods=$(find Packages/Features -mindepth 1 -maxdepth 1 -type d -exec basename {} \;)
    for src in Packages/Features/*/Sources; do
        own=$(basename "$(dirname "$src")")
        siblings=$(printf '%s\n' "$feature_mods" | grep -v "^$own$" || true)
        forbidden="KTStackKit"
        [ -n "$siblings" ] && forbidden="$forbidden|$(printf '%s' "$siblings" | paste -sd'|' -)"
        check_imports "Feature $own" "$src" "$forbidden"
    done
fi

if [ "$VIOLATIONS" -gt 0 ]; then
    printf '\narchitecture-check: %d violation(s). See docs/architecture/dependency-rules.md\n' "$VIOLATIONS" >&2
    exit 1
fi
echo "architecture-check: package boundaries clean"
