#!/usr/bin/env bash
# Integration harness: boots a real nginx (+ php-fpm) stack from production-generated configs
# against a temp root and asserts over real HTTP(S). Too slow for the commit/push hooks;
# run it per session and before merges. See KTStackKitTests/Integration/.
set -euo pipefail
cd "$(dirname "$0")/.."

BIN_DIR="KTStack/Resources/bin"
for bin in nginx mkcert; do
    if [[ ! -x "$BIN_DIR/$bin" ]]; then
        echo "❌ missing $BIN_DIR/$bin: bundled binaries are gitignored build artifacts." >&2
        echo "   Build/stage them first (scripts/build-nginx-relocatable.sh and friends; see README 'Build from source')." >&2
        exit 1
    fi
done

DERIVED=".build-ci"
LOG_DIR="$DERIVED/logs"
mkdir -p "$LOG_DIR"

if [[ ! -f KTStack.xcodeproj/project.pbxproj || project.yml -nt KTStack.xcodeproj/project.pbxproj ]]; then
    xcodegen generate
fi

LOG="$LOG_DIR/integration.log"
START=$SECONDS
echo "=== integration tests (real nginx/php-fpm stack) ==="
if TEST_RUNNER_KTSTACK_INTEGRATION=1 \
   TEST_RUNNER_KTSTACK_BIN_DIR="$PWD/$BIN_DIR" \
   xcodebuild -project KTStack.xcodeproj -scheme KTStackKit-Tests -destination 'platform=macOS' \
       -derivedDataPath "$DERIVED" \
       -only-testing:KTStackKitTests/NginxStackIntegrationTests \
       -only-testing:KTStackKitTests/PHPSiteServingIntegrationTests \
       test >"$LOG" 2>&1; then
    # A green xcodebuild can still mean zero real coverage: the env flag not reaching the test
    # runner skips every test, and a stale pbxproj (folder-glob target) drops the classes so
    # -only-testing matches nothing. Fail both instead of reporting a false pass.
    if grep -q "integration tests run only with KTSTACK_INTEGRATION=1" "$LOG"; then
        echo "❌ tests were skipped: KTSTACK_INTEGRATION did not reach the test runner. See $LOG" >&2
        exit 1
    fi
    PASSED=$(grep -Ec "Test Case .* passed" "$LOG" || true)
    if [[ $PASSED -eq 0 ]]; then
        echo "❌ no integration test executed (stale Xcode project? run: xcodegen generate). See $LOG" >&2
        exit 1
    fi
    echo "✅ integration tests passed ($PASSED tests, $((SECONDS - START))s)"
else
    echo "❌ integration tests failed ($((SECONDS - START))s), see $LOG" >&2
    grep -E "error:|Test Case.*failed|Failing tests|Skipped" "$LOG" | tail -30 >&2 || tail -40 "$LOG" >&2
    exit 1
fi
