#!/usr/bin/env bash
# Build a relocatable, statically-linked PHP (cli + php-fpm) via static-php-cli (spc) and
# vendor both into KDWarm/Resources/bin.
#
# Why static-php-cli: it produces a self-contained PHP with no Cellar/Homebrew dylib
# dependencies (otool shows only system /usr/lib + /System frameworks) — proven relocatable
# by the Foundations Spike (s3-relocatable/run-s3-php.sh). The prebuilt downloads at
# dl.static-php.dev ship the CLI only, so php-fpm MUST be compiled here.
#
# Extension set: a lean web-dev baseline (MySQL/SQLite PDO, curl+openssl TLS, mbstring,
# opcache). Heavy-dep extensions (gd, intl, zip) are intentionally omitted to keep the first
# build fast and reliable; extend EXTENSIONS below when a later phase needs them.
#
# JIT: opcache is included → PHP's JIT is available (opcache.jit). This requires the
# `com.apple.security.cs.allow-jit` entitlement once the app is notarized — RECORDED for
# Phase 9 (this dev build is un-notarized so JIT runs without it).
#
# Arch scope: builds for the HOST arch (arm64 on Apple Silicon). Universal is assembled in
# Phase 9 by building each arch and `lipo -create`-ing the results.
#
# Output: KDWarm/Resources/bin/php, KDWarm/Resources/bin/php-fpm
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$PWD"

PHP_VER="${PHP_VER:-8.4}"
ARCH="${ARCH:-$(uname -m)}"                    # arm64 | x86_64 (spc target token below)
OUT="${OUT:-$ROOT/KDWarm/Resources/bin}"
BUILD="${BUILD:-$ROOT/.build-cache/php-$ARCH}" # scratch (gitignored)

# spc arch token: arm64 → aarch64
case "$ARCH" in
  arm64)  SPC_ARCH="aarch64" ;;
  x86_64) SPC_ARCH="x86_64" ;;
  *) echo "unsupported ARCH=$ARCH" >&2; exit 2 ;;
esac

EXTENSIONS="${EXTENSIONS:-bcmath,curl,dom,fileinfo,filter,mbstring,mysqli,opcache,openssl,pdo,pdo_mysql,pdo_sqlite,phar,session,sqlite3,tokenizer,xml,zlib}"

echo "=== static-php-cli build — PHP ${PHP_VER} (${ARCH}) ==="
echo "    extensions: $EXTENSIONS"
mkdir -p "$BUILD" "$OUT"
cd "$BUILD"

SPC="$BUILD/spc"
if [[ ! -x "$SPC" ]]; then
    echo "=== fetch spc (static-php-cli) ==="
    curl -fsSL "https://dl.static-php.dev/static-php-cli/spc-bin/nightly/spc-macos-${SPC_ARCH}" -o "$SPC"
    chmod +x "$SPC"
fi
"$SPC" --version

echo "=== doctor (auto-fix build prerequisites) ==="
"$SPC" doctor --auto-fix

echo "=== download PHP ${PHP_VER} source + extension deps ==="
"$SPC" download --with-php="$PHP_VER" --for-extensions="$EXTENSIONS" --prefer-pre-built

echo "=== build (cli + fpm), static ==="
"$SPC" build "$EXTENSIONS" --build-cli --build-fpm

PHP_BIN="$BUILD/buildroot/bin/php"
# static-php-cli stages php-fpm in buildroot/bin (not sbin).
FPM_BIN="$BUILD/buildroot/bin/php-fpm"
[[ -x "$PHP_BIN" ]] || { echo "php not produced at $PHP_BIN" >&2; ls -R "$BUILD/buildroot" >&2; exit 1; }
[[ -x "$FPM_BIN" ]] || { echo "php-fpm not produced at $FPM_BIN" >&2; ls -R "$BUILD/buildroot" >&2; exit 1; }

echo "=== otool -L (relocatability gate) ==="
for b in "$PHP_BIN" "$FPM_BIN"; do
    otool -L "$b"
    BAD=$(otool -L "$b" | tail -n +2 | awk '{print $1}' \
            | grep -vE '^(/usr/lib/|/System/|@rpath/|@executable_path/|@loader_path/)' || true)
    [[ -z "$BAD" ]] || { echo "  ✗ leaked dylib refs in $(basename "$b"):"; echo "$BAD" | sed 's/^/    /'; exit 1; }
    echo "  ✓ $(basename "$b") clean"
done

cp "$PHP_BIN" "$OUT/php"
cp "$FPM_BIN" "$OUT/php-fpm"
chmod +x "$OUT/php" "$OUT/php-fpm"
# Ad-hoc sign so BinaryStager's `codesign --verify` passes in dev and the cdhash seals the
# binary against post-stage tampering. Phase 9 replaces this with a Developer ID signature.
codesign --force --sign - "$OUT/php" "$OUT/php-fpm"

echo "=== health probe ==="
"$OUT/php" -v | head -1
echo "  php -r '6*7' => $("$OUT/php" -r 'echo 6*7;')"
"$OUT/php-fpm" -t -v 2>&1 | head -2 || true
echo "=== vendored → $OUT/php, $OUT/php-fpm ==="
echo "PHP BUILD OK"
