#!/usr/bin/env bash
# Generate/refresh the Sparkle EdDSA-signed appcast from a folder of release artifacts (.dmg/.zip).
# Wraps Sparkle's `generate_appcast`, which computes the EdDSA signature for each update (using the
# private key stored in the Keychain by `generate_keys`) and writes/updates appcast.xml.
#
# Usage: scripts/release/update-appcast.sh <releases-dir>   # dir holding KTStack-<ver>.dmg
# The EdDSA PRIVATE key must be in the Keychain (or pass --ed-key-file in CI); never commit it.
#
# Updates are hosted on GitHub Releases. Set DOWNLOAD_URL_PREFIX so each enclosure points at the
# release asset, e.g.:
#   DOWNLOAD_URL_PREFIX="https://github.com/KTStackAPP/KTStack/releases/download/v0.7.0/" \
#     scripts/release/update-appcast.sh <releases-dir>
# Then upload appcast.xml AND the .dmg to that release; SUFeedURL reads
#   https://github.com/KTStackAPP/KTStack/releases/latest/download/appcast.xml
set -euo pipefail
# shellcheck source=scripts/release/lib-appcast.sh
source "$(dirname "$0")/lib-appcast.sh"
RELEASES="${1:?usage: update-appcast.sh <releases-dir-with-dmgs>}"
DD="${DERIVED_DATA:-$HOME/Library/Developer/Xcode/DerivedData}"
PREFIX_ARGS=()
[[ -n "${DOWNLOAD_URL_PREFIX:-}" ]] && PREFIX_ARGS=(--download-url-prefix "$DOWNLOAD_URL_PREFIX")

# Prefer this project's resolved Sparkle (so the tool version matches the linked framework); fall
# back to any. Override with GENERATE_APPCAST=/path to pin explicitly in CI.
GEN_APPCAST="${GENERATE_APPCAST:-}"
[[ -x "${GEN_APPCAST:-}" ]] || GEN_APPCAST="$(find "$DD" -path "*sparkle*/bin/generate_appcast" -type f 2>/dev/null | head -1 || true)"
[[ -x "${GEN_APPCAST:-}" ]] || { echo "generate_appcast not found — build the app once so Sparkle resolves (or set DERIVED_DATA)." >&2; exit 1; }

shopt -s nullglob
DMGS=( "$RELEASES"/*.dmg "$RELEASES"/*.zip )
shopt -u nullglob

if [[ ${#DMGS[@]} -le 1 ]]; then
    echo "=== generate_appcast over $RELEASES ==="
    "$GEN_APPCAST" "${PREFIX_ARGS[@]}" "$RELEASES"
else
    echo "=== per-arch appcast: generating ${#DMGS[@]} archives separately then merging ==="
    ITEMS=""
    for d in "${DMGS[@]}"; do
        sub="$(mktemp -d)"; cp "$d" "$sub/"
        "$GEN_APPCAST" "${PREFIX_ARGS[@]}" "$sub" >/dev/null
        ITEMS+="$(sed -n '/<item>/,/<\/item>/p' "$sub/appcast.xml")"$'\n'
        rm -rf "$sub"
    done
    {
        echo '<?xml version="1.0" standalone="yes"?>'
        echo '<rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" version="2.0">'
        echo '    <channel>'
        echo '        <title>KTStack</title>'
        printf '%s' "$ITEMS"
        echo '    </channel>'
        echo '</rss>'
    } > "$RELEASES/appcast.xml"
fi
tag_arm64_items "$RELEASES/appcast.xml"
echo "appcast: $RELEASES/appcast.xml ($(grep -cE '<item>' "$RELEASES/appcast.xml") item(s))"
echo "Next: upload appcast.xml AND every .dmg to the matching GitHub Release (gh release upload <tag> …)."
