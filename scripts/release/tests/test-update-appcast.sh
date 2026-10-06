#!/usr/bin/env bash
# Runs update-appcast.sh against a stub generate_appcast and checks the arch tagging the DMG smoke
# test requires: the -arm64 item carries sparkle:hardwareRequirements, the -x86_64 item does not.
# Also checks every item embeds the CHANGELOG section for its version as its release notes, and that
# a version with no notes fails instead of shipping an empty update dialog.
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
        notes="${f%.dmg}.html"
        [[ -f "$notes" ]] && echo "            <description><![CDATA[$(cat "$notes")]]></description>"
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

cat > "$WORK/CHANGELOG.md" <<'MD'
# Changelog

## 1.0.1 — 2026-01-02

### Fixed

- Not this one.

## 1.0 — 2026-01-01

### Added

- **Backups** run `nightly` & keep <N> archives,
  wrapped onto a second line.

Plain paragraph.

## 0.9 — 2025-12-01

- Older.
MD

export RELEASE_NOTES="$WORK/CHANGELOG.md"
mkdir -p "$WORK/both"
touch "$WORK/both/KTStack-1.0-arm64.dmg" "$WORK/both/KTStack-1.0-x86_64.dmg"
GENERATE_APPCAST="$WORK/generate_appcast" "$ROOT/scripts/release/update-appcast.sh" "$WORK/both" >/dev/null
check "$WORK/both/appcast.xml"
[[ "$(grep -c '<item>' "$WORK/both/appcast.xml")" == 2 ]] || fail "expected two items"
[[ "$(grep -c '<description>' "$WORK/both/appcast.xml")" == 2 ]] || fail "every item must embed release notes"
expected='<h3>Added</h3>
<ul>
<li><b>Backups</b> run <code>nightly</code> &amp; keep &lt;N&gt; archives, wrapped onto a second line.</li>
</ul>
<p>Plain paragraph.</p>'
source "$ROOT/scripts/release/lib-appcast.sh"
[[ "$(changelog_section 1.0 "$WORK/CHANGELOG.md" | markdown_to_html)" == "$expected" ]] || fail "unexpected release notes HTML"
grep -q 'Not this one\|Older' "$WORK/both/appcast.xml" && fail "notes leaked from another version"
[[ ! -e "$WORK/both/KTStack-1.0-arm64.html" ]] || fail "per-arch run must not leave notes in the releases dir"

mkdir -p "$WORK/single"
touch "$WORK/single/KTStack-1.0-arm64.dmg"
GENERATE_APPCAST="$WORK/generate_appcast" "$ROOT/scripts/release/update-appcast.sh" "$WORK/single" >/dev/null
check "$WORK/single/appcast.xml"
grep -q '<h3>Added</h3>' "$WORK/single/appcast.xml" || fail "single archive must embed release notes"

mkdir -p "$WORK/custom"
touch "$WORK/custom/KTStack-1.0-arm64.dmg" "$WORK/custom/KTStack-1.0-x86_64.dmg"
echo '<p>Hand-written.</p>' > "$WORK/custom/KTStack-1.0-x86_64.html"
GENERATE_APPCAST="$WORK/generate_appcast" "$ROOT/scripts/release/update-appcast.sh" "$WORK/custom" >/dev/null
[[ "$(grep -c 'Hand-written' "$WORK/custom/appcast.xml")" == 1 ]] || fail "a hand-written .html must win"
[[ "$(grep -c '<h3>Added</h3>' "$WORK/custom/appcast.xml")" == 1 ]] || fail "the other item still gets CHANGELOG notes"

mkdir -p "$WORK/missing"
touch "$WORK/missing/KTStack-2.0-arm64.dmg" "$WORK/missing/KTStack-2.0-x86_64.dmg"
GENERATE_APPCAST="$WORK/generate_appcast" "$ROOT/scripts/release/update-appcast.sh" "$WORK/missing" >/dev/null 2>&1 \
    && fail "a version without a CHANGELOG section must fail, not ship without notes"
[[ ! -e "$WORK/missing/appcast.xml" ]] || fail "no appcast may be written when notes are missing"

tag_arm64_items "$WORK/both/appcast.xml"
[[ "$(grep -c hardwareRequirements "$WORK/both/appcast.xml")" == 1 ]] || fail "tagging must be idempotent"

echo "update-appcast arch tagging and release notes: ok"
