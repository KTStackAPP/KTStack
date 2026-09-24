#!/usr/bin/env bash
# Runs update-appcast.sh against a stub generate_appcast and checks the arch tagging the DMG smoke
# test requires: the -arm64 item carries sparkle:hardwareRequirements, the -x86_64 item does not.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

cat > "$WORK/generate_appcast" <<'STUB'
#!/usr/bin/env bash
dir="${@: -1}"
{
    echo '<?xml version="1.0" standalone="yes"?>'
    echo '<rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" version="2.0">'
    echo '    <channel>'
    for f in "$dir"/*.dmg; do
        echo '        <item>'
        echo "            <enclosure url=\"https://example.invalid/$(basename "$f")\" length=\"1\" type=\"application/octet-stream\"/>"
        echo '        </item>'
    done
    echo '    </channel>'
    echo '</rss>'
} > "$dir/appcast.xml"
STUB
chmod +x "$WORK/generate_appcast"

fail() { echo "FAIL: $*" >&2; exit 1; }

check() {
    local appcast="$1"
    local arm x86
    arm="$(awk '/<item>/{b=""} {b=b $0} /<\/item>/{ if (b ~ /-arm64\.dmg/) print b }' "$appcast")"
    x86="$(awk '/<item>/{b=""} {b=b $0} /<\/item>/{ if (b ~ /-x86_64\.dmg/) print b }' "$appcast")"
    [[ "$arm" == *"<sparkle:hardwareRequirements>arm64</sparkle:hardwareRequirements>"* ]] || fail "arm64 item not tagged"
    [[ -z "$x86" || "$x86" != *hardwareRequirements* ]] || fail "x86_64 item must not be tagged"
}

mkdir -p "$WORK/both"
touch "$WORK/both/KTStack-1.0-arm64.dmg" "$WORK/both/KTStack-1.0-x86_64.dmg"
GENERATE_APPCAST="$WORK/generate_appcast" "$ROOT/scripts/release/update-appcast.sh" "$WORK/both" >/dev/null
check "$WORK/both/appcast.xml"
[[ "$(grep -c '<item>' "$WORK/both/appcast.xml")" == 2 ]] || fail "expected two items"

mkdir -p "$WORK/single"
touch "$WORK/single/KTStack-1.0-arm64.dmg"
GENERATE_APPCAST="$WORK/generate_appcast" "$ROOT/scripts/release/update-appcast.sh" "$WORK/single" >/dev/null
check "$WORK/single/appcast.xml"

source "$ROOT/scripts/release/lib-appcast.sh"
tag_arm64_items "$WORK/both/appcast.xml"
[[ "$(grep -c hardwareRequirements "$WORK/both/appcast.xml")" == 1 ]] || fail "tagging must be idempotent"

echo "update-appcast arch tagging: ok"
