#!/usr/bin/env bash
# Local quality gate: lint + KTStackKit-Tests (+ Release build of the app in full mode).
# Runs on the dev machine, no GitHub dependency. Wired into git hooks by scripts/install-git-hooks.sh.
set -euo pipefail
cd "$(dirname "$0")/.."

QUICK=0
case "${1:-}" in
    --quick) QUICK=1 ;;
    "") ;;
    *) echo "usage: $0 [--quick]" >&2; exit 2 ;;
esac

# Dedicated derived data so gate runs stay reproducible and never race the release build in .build-xcode.
DERIVED=".build-ci"
LOG_DIR="$DERIVED/logs"
mkdir -p "$LOG_DIR"

STAGE_START=0

begin() {
    STAGE_START=$SECONDS
    printf '\n=== %s ===\n' "$1"
}

ok() {
    printf '✅ %s (%ds)\n' "$1" "$((SECONDS - STAGE_START))"
}

# xcodebuild logs end with unrelated observer noise, so surface the error lines, not the tail.
fail() {
    printf '❌ %s (%ds) — see %s\n' "$1" "$((SECONDS - STAGE_START))" "$2"
    if ! grep -E 'error:|warning: .*violation|failed|FAILED' "$2" | tail -20; then
        tail -40 "$2"
    fi
    exit 1
}

if [[ ! -f KTStack.xcodeproj/project.pbxproj || project.yml -nt KTStack.xcodeproj/project.pbxproj ]]; then
    begin "xcodegen generate"
    LOG="$LOG_DIR/xcodegen.log"
    xcodegen generate >"$LOG" 2>&1 || fail "xcodegen" "$LOG"
    ok "project regenerated"
fi

begin "lint"
LOG="$LOG_DIR/lint.log"
scripts/lint.sh >"$LOG" 2>&1 || fail "lint" "$LOG"
ok "lint"

begin "KTStackKit-Tests"
LOG="$LOG_DIR/tests.log"
xcodebuild -project KTStack.xcodeproj -scheme KTStackKit-Tests -destination 'platform=macOS' \
    -derivedDataPath "$DERIVED" test >"$LOG" 2>&1 || fail "tests" "$LOG"
ok "tests"

if [[ $QUICK -eq 1 ]]; then
    printf '\nGate passed (quick).\n'
    exit 0
fi

begin "Release build (KTStack)"
LOG="$LOG_DIR/build.log"
xcodebuild -project KTStack.xcodeproj -scheme KTStack -destination 'platform=macOS' \
    -configuration Release -derivedDataPath "$DERIVED" build >"$LOG" 2>&1 || fail "build" "$LOG"
ok "Release build"

printf '\nGate passed (full).\n'
