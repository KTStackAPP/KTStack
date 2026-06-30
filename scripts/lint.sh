#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

if ! command -v swiftformat >/dev/null 2>&1; then
  echo "swiftformat not found. Install: brew install swiftformat" >&2
  exit 127
fi

if ! command -v swiftlint >/dev/null 2>&1; then
  echo "swiftlint not found. Install: brew install swiftlint" >&2
  exit 127
fi

echo "swiftformat --lint ."
swiftformat --lint . || echo "swiftformat reported style drift (non-blocking)."

echo "swiftlint"
swiftlint --strict=false
