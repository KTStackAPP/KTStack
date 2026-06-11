#!/usr/bin/env bash
# Build every requested PHP version via build-php-static.sh (static-php-cli). Default builds the full
# bundled-set order: 8.4 (the bundled default → also flat in Resources/bin) then 8.1/8.3/7.4 (which
# produce on-demand artifacts only). Each version is a separate static build with a fixed extension
# matrix — expect ~15-40 min EACH.
#
# Usage: scripts/build-php-versions.sh [VER ...]        # e.g. scripts/build-php-versions.sh 8.3 8.1
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$PWD"

VERSIONS=("${@:-8.4 8.3 8.1 7.4}")
# Re-split when the default single-arg string was used.
[[ $# -eq 0 ]] && VERSIONS=(8.4 8.3 8.1 7.4)

echo "=== build PHP versions: ${VERSIONS[*]} ==="
for ver in "${VERSIONS[@]}"; do
    echo ""
    echo "######## PHP $ver ########"
    PHP_VER="$ver" bash "$ROOT/scripts/build-php-static.sh"
done
echo "ALL PHP VERSIONS DONE: ${VERSIONS[*]}"
