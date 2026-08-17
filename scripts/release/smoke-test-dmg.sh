#!/usr/bin/env bash
# Cold-verify a built DMG the way a user's machine sees it: mount read-only, strict-verify every
# nested Mach-O, check the helper's designated identifier, Gatekeeper-assess, bounded-launch the
# app from a temp copy, and sanity-check the per-arch appcast.
#
# Usage: scripts/release/smoke-test-dmg.sh <path-to-dmg> [--no-launch]
#   APPCAST=<path>   appcast.xml to check (default: appcast.xml next to the DMG; skipped if absent)
#
# Release gate: 0.2.8 shipped a Mailpit binary with an invalid signature (#28) and a helper signed
# with the wrong identifier (#25). Both survived the pre-DMG checks in sign-all-binaries.sh because
# nothing re-verified the artifact users actually download.
set -uo pipefail

DMG="${1:?usage: smoke-test-dmg.sh <path-to-dmg> [--no-launch]}"
LAUNCH=1
[[ "${2:-}" == "--no-launch" ]] && LAUNCH=0
[[ -f "$DMG" ]] || { echo "❌ not a file: $DMG" >&2; exit 2; }
DMG="$(cd "$(dirname "$DMG")" && pwd)/$(basename "$DMG")"

FAILURES=()
WARNINGS=()
pass() { printf '  ✅ %s\n' "$1"; }
warn() { printf '  ⚠️  %s\n' "$1"; WARNINGS+=("$1"); }
fail() { printf '  ❌ %s\n' "$1"; FAILURES+=("$1"); }

# -P: /tmp is a symlink to /private/tmp and `mount` reports the resolved path, so an unresolved
# mountpoint leaves the image attached after the run and the next run hits "Resource busy".
MOUNT="$(cd "$(mktemp -d /tmp/ktstack-smoke-mnt.XXXXXX)" && pwd -P)"
LAUNCH_DIR=""
LAUNCH_PID=""
MOUNTED=0
cleanup() {
    # Kill before the rm: an app left running out of a deleted bundle keeps holding launchd jobs.
    if [[ -n "$LAUNCH_PID" ]] && kill -0 "$LAUNCH_PID" 2>/dev/null; then
        kill -TERM "$LAUNCH_PID" 2>/dev/null || true
        for _ in $(seq 1 10); do kill -0 "$LAUNCH_PID" 2>/dev/null || break; sleep 0.5; done
        kill -0 "$LAUNCH_PID" 2>/dev/null && kill -KILL "$LAUNCH_PID" 2>/dev/null || true
    fi
    [[ -n "$LAUNCH_DIR" && -d "$LAUNCH_DIR" ]] && rm -rf "$LAUNCH_DIR"
    if [[ $MOUNTED -eq 1 ]]; then
        hdiutil detach "$MOUNT" -quiet 2>/dev/null || hdiutil detach "$MOUNT" -force -quiet 2>/dev/null || true
    fi
    rmdir "$MOUNT" 2>/dev/null || true
}
trap cleanup EXIT

echo "🔎 KTStack DMG smoke test"
echo "   $DMG"

echo ""
echo "=== 0. mount read-only ==="
if ! hdiutil attach "$DMG" -readonly -nobrowse -noautoopen -mountpoint "$MOUNT" >/dev/null; then
    echo "❌ cannot mount $DMG" >&2
    exit 1
fi
MOUNTED=1
APP="$(find "$MOUNT" -maxdepth 2 -name "*.app" -type d -print -quit)"
[[ -n "$APP" ]] || { echo "❌ no .app inside the DMG" >&2; exit 1; }
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist" 2>/dev/null || echo '?')"
pass "mounted: $(basename "$APP") $VERSION"

echo ""
echo "=== 1. strict codesign of the app and every nested Mach-O ==="
if codesign --verify --strict --verbose=4 "$APP" 2>&1 | sed 's/^/     /'; then
    pass "app bundle seal"
else
    fail "app bundle seal (codesign --verify --strict)"
fi

# Same check BinaryStager runs before executing a staged binary, applied to every shipped Mach-O.
checked=0
before=${#FAILURES[@]}
while IFS= read -r -d '' f; do
    file -b "$f" 2>/dev/null | grep -q "Mach-O" || continue
    checked=$((checked + 1))
    if ! err="$(codesign --verify --strict "$f" 2>&1)"; then
        fail "nested Mach-O: ${f#"$APP/"}: ${err//$'\n'/ }"
    fi
done < <(find "$APP" -type f -print0)
[[ ${#FAILURES[@]} -eq $before ]] && pass "$checked nested Mach-O verified"

echo ""
echo "=== 2. helper designated identifier (regression: #25) ==="
HELPER="$(find "$APP" -type f -name 'KTStackHelper' -print -quit)"
if [[ -z "$HELPER" ]]; then
    fail "KTStackHelper not embedded in the app"
else
    REQ="$(codesign -d -r- "$HELPER" 2>&1)"
    if grep -q 'identifier "com\.ktstack\.helper"' <<<"$REQ"; then
        pass "helper identifier com.ktstack.helper"
    else
        fail "helper designated requirement lacks identifier \"com.ktstack.helper\": ${REQ//$'\n'/ }"
    fi
    APP_TEAM="$(codesign -dvv "$APP" 2>&1 | sed -n 's/^TeamIdentifier=//p')"
    HELPER_TEAM="$(codesign -dvv "$HELPER" 2>&1 | sed -n 's/^TeamIdentifier=//p')"
    if [[ -n "$APP_TEAM" && "$APP_TEAM" == "$HELPER_TEAM" ]]; then
        pass "app/helper share team $APP_TEAM"
    else
        fail "team mismatch: app '$APP_TEAM' != helper '$HELPER_TEAM'"
    fi
fi

echo ""
echo "=== 3. Gatekeeper / notarization ==="
online() { curl -sf --max-time 5 -o /dev/null https://www.apple.com/; }
assess() { # <label> <spctl args...>
    local label="$1"; shift
    local out
    if out="$("$@" 2>&1)"; then
        pass "$label: $(sed -n 's/^.*source=/source=/p' <<<"$out" | head -1)"
    elif online; then
        fail "$label rejected: ${out//$'\n'/ }"
    else
        warn "$label skipped: offline, spctl cannot assess"
    fi
}
if xcrun stapler validate "$APP" >/dev/null 2>&1; then
    pass "notarization ticket stapled to the app"
else
    fail "app has no stapled notarization ticket"
fi
if xcrun stapler validate "$DMG" >/dev/null 2>&1; then
    pass "notarization ticket stapled to the DMG"
else
    fail "DMG has no stapled notarization ticket"
fi
assess "spctl app" spctl --assess --type execute --verbose=4 "$APP"
assess "spctl DMG" spctl --assess --type open --context context:primary-signature --verbose=4 "$DMG"

echo ""
echo "=== 4. bounded launch from a temp copy ==="
BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Contents/Info.plist" 2>/dev/null || echo '')"
APP_ARCHS="$(lipo -archs "$APP/Contents/MacOS/$(basename "$APP" .app)" 2>/dev/null || echo '')"
runnable_here() { # a thin DMG for the other arch only runs through Rosetta
    [[ " $APP_ARCHS " == *" $(uname -m) "* ]] && return 0
    [[ "$(uname -m)" == "arm64" ]] && pgrep -q oahd
}
if [[ $LAUNCH -eq 0 ]]; then
    warn "launch skipped (--no-launch)"
elif ! runnable_here; then
    warn "launch skipped: DMG is $APP_ARCHS, host is $(uname -m) with no Rosetta"
elif pgrep -x "$(basename "$APP" .app)" >/dev/null; then
    # A second instance would fight the running one over launchd jobs and app-support state.
    warn "launch skipped: $(basename "$APP" .app) is already running, quit it and re-run for full coverage"
else
    # -P again: ps/pgrep report the resolved /private/tmp path, so an unresolved one never matches.
    LAUNCH_DIR="$(cd "$(mktemp -d /tmp/ktstack-smoke-run.XXXXXX)" && pwd -P)"
    ditto "$APP" "$LAUNCH_DIR/$(basename "$APP")"
    EXEC="$LAUNCH_DIR/$(basename "$APP")/Contents/MacOS/$(basename "$APP" .app)"
    if open -n "$LAUNCH_DIR/$(basename "$APP")" 2>/dev/null; then
        for _ in $(seq 1 20); do
            LAUNCH_PID="$(pgrep -f "^$EXEC$" | head -1)"
            [[ -n "$LAUNCH_PID" ]] && break
            sleep 0.5
        done
        if [[ -z "$LAUNCH_PID" ]]; then
            fail "app did not start from the temp copy"
        else
            sleep 8
            if kill -0 "$LAUNCH_PID" 2>/dev/null; then
                pass "app stayed up 8s (pid $LAUNCH_PID${BUNDLE_ID:+, $BUNDLE_ID})"
            else
                fail "app exited within 8s of launch"
            fi
        fi
    else
        fail "open(1) refused to launch the temp copy"
    fi
fi

echo ""
echo "=== 5. appcast sanity ==="
APPCAST="${APPCAST:-$(dirname "$DMG")/appcast.xml}"
if [[ ! -f "$APPCAST" ]]; then
    warn "appcast skipped: no $APPCAST (run update-appcast.sh, then re-run with APPCAST=…)"
else
    ITEMS="$(awk '
        /<item>/ { inb = 1; blk = "" }
        inb { blk = blk $0 "\n" }
        /<\/item>/ {
            inb = 0
            url = ""
            if (match(blk, /url="[^"]+"/)) url = substr(blk, RSTART + 5, RLENGTH - 6)
            print (blk ~ /hardwareRequirements/ ? "hw" : "-") "\t" url
        }' "$APPCAST")"
    if [[ -z "$ITEMS" ]]; then
        fail "appcast has no <item>"
    else
        found=0
        while IFS=$'\t' read -r hw url; do
            base="$(basename "$url")"
            [[ "$base" == "$(basename "$DMG")" ]] && found=1
            case "$base" in
                *-arm64.dmg)
                    [[ "$hw" == "hw" ]] && pass "$base carries sparkle:hardwareRequirements" \
                        || fail "$base is the arm64 item but has no sparkle:hardwareRequirements" ;;
                *-x86_64.dmg)
                    [[ "$hw" == "-" ]] && pass "$base has no sparkle:hardwareRequirements" \
                        || fail "$base is the x86_64 item and must not carry sparkle:hardwareRequirements" ;;
                *) warn "appcast item with no arch suffix: $base" ;;
            esac
        done <<<"$ITEMS"
        [[ $found -eq 1 ]] && pass "$(basename "$DMG") is enclosed in the appcast" \
            || fail "$(basename "$DMG") missing from $APPCAST"
    fi
fi

echo ""
if (( ${#WARNINGS[@]} )); then
    echo "⚠️  ${#WARNINGS[@]} warning(s):"
    printf '   - %s\n' "${WARNINGS[@]}"
fi
if (( ${#FAILURES[@]} )); then
    echo "❌ SMOKE TEST FAILED: ${#FAILURES[@]} problem(s):"
    printf '   - %s\n' "${FAILURES[@]}"
    exit 1
fi
echo "✅ SMOKE TEST PASSED: $(basename "$DMG") ($VERSION)"
