#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
ROOT="$PWD"
source "$ROOT/scripts/lib-relocatable.sh"

DEV_ID="${DEV_ID:?set DEV_ID to your 'Developer ID Application: … (TEAMID)' identity}"
TEAM_ID="${TEAM_ID:-$(printf '%s' "$DEV_ID" | sed -n 's/.*(\([A-Z0-9]\{10\}\)).*/\1/p')}"
ARCH="${ARCH:-$(uname -m)}"
ARTIFACT_PREFIX="${ARTIFACT_PREFIX:-php}"
ARTIFACTS="${ARTIFACTS:-$ROOT/.build-cache/artifacts}"
NOTARIZE_DIR="${NOTARIZE_DIR:-$ROOT/.build-cache/notarize-$ARTIFACT_PREFIX-$ARCH}"
SHA_OUT="${SHA_OUT:-$ARTIFACTS/$ARTIFACT_PREFIX-signed-sha.tsv}"

[[ -n "$TEAM_ID" ]] || { echo "cannot derive TEAM_ID from DEV_ID" >&2; exit 1; }
echo "=== Developer-ID sign — identity: $DEV_ID (team $TEAM_ID) ==="

rm -rf "$NOTARIZE_DIR"; mkdir -p "$NOTARIZE_DIR"
: > "$SHA_OUT"

sign_macho() {
    local f="$1"
    codesign --force --options runtime --timestamp --sign "$DEV_ID" "$f" >/dev/null 2>&1
    local tid
    tid="$(codesign -dvv "$f" 2>&1 | sed -n 's/^TeamIdentifier=//p')"
    [[ "$tid" == "$TEAM_ID" ]] || { echo "  ✗ $(basename "$f"): team $tid != $TEAM_ID" >&2; return 1; }
    codesign --verify --strict "$f" >/dev/null 2>&1 || { echo "  ✗ $(basename "$f"): verify failed" >&2; return 1; }
}

sign_tree() {
    local dir="$1" f
    while IFS= read -r f; do sign_macho "$f" || return 1; done < <(find "$dir" -type f -name '*.dylib')
    while IFS= read -r f; do sign_macho "$f" || return 1; done < <(find "$dir" -type f -name '*.so')
    while IFS= read -r f; do
        [[ "$f" == *.dylib || "$f" == *.so ]] && continue
        file "$f" | grep -q 'Mach-O' && { sign_macho "$f" || return 1; }
    done < <(find "$dir" -type f)
}

process_artifact() {
    local tgz="$1" name top work
    name="$(basename "$tgz")"
    work="$(mktemp -d)"
    tar -xf "$tgz" -C "$work"
    top="$(find "$work" -maxdepth 1 -mindepth 1 -type d | head -1)"
    [[ -n "$top" ]] || { echo "  ✗ $name: no top dir" >&2; rm -rf "$work"; return 1; }
    sign_tree "$top" || { rm -rf "$work"; return 1; }
    cp -R "$top" "$NOTARIZE_DIR/${name%.tar.gz}"
    ( cd "$work" && tar -czf "$ROOT/$tgz.tmp" "$(basename "$top")" ) 2>/dev/null || \
        tar -czf "$tgz.tmp" -C "$work" "$(basename "$top")"
    mv "$tgz.tmp" "$tgz"
    local sha; sha="$(sha256_of "$tgz")"
    echo "$sha  $name" > "$tgz.sha256"
    printf '%s\t%s\n' "$name" "$sha" >> "$SHA_OUT"
    echo "  ✓ $name  sha:${sha:0:12}…"
    rm -rf "$work"
}

FAILED=()
for tgz in "$ARTIFACTS"/"$ARTIFACT_PREFIX"-*-"$ARCH".tar.gz; do
    [[ -e "$tgz" ]] || continue
    process_artifact "$tgz" || FAILED+=("$(basename "$tgz")")
done

echo ""
echo "=== signed $(wc -l < "$SHA_OUT" | tr -d ' ') artifacts; team-id $TEAM_ID uniform ==="
echo "notarize staging: $NOTARIZE_DIR"
if [[ ${#FAILED[@]} -gt 0 ]]; then echo "✗ FAILED: ${FAILED[*]}" >&2; exit 1; fi
echo "next: zip $NOTARIZE_DIR + notarytool submit --wait, then publish + update manifest sha from $SHA_OUT"
