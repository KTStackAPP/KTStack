#!/usr/bin/env bash
# Build a relocatable dnsmasq and vendor it into KTStack/Resources/bin.
#
# dnsmasq has no third-party dependencies — it links only the system libc/libresolv — so the
# built binary is already relocatable (otool shows only /usr/lib + /System). The privileged
# helper (Phase 4) runs it as a launchd daemon bound to 127.0.0.1:53 with `address=/.test/127.0.0.1`.
#
# Arch scope: host arch (arm64). Universal is assembled in Phase 9 via lipo.
# Output: KTStack/Resources/bin/dnsmasq
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$PWD"

DNSMASQ_VER="${DNSMASQ_VER:-2.90}"
ARCH="${ARCH:-$(uname -m)}"
OUT="${OUT:-$ROOT/KTStack/Resources/bin}"
BUILD="${BUILD:-$ROOT/.build-cache/dnsmasq-$ARCH}"
SRC="$BUILD/dnsmasq-${DNSMASQ_VER}"

echo "=== dnsmasq ${DNSMASQ_VER} (${ARCH}) — relocatable build ==="
rm -rf "$BUILD"; mkdir -p "$BUILD" "$OUT"

echo "=== download source ==="
curl -fsSL "https://thekelleys.org.uk/dnsmasq/dnsmasq-${DNSMASQ_VER}.tar.xz" -o "$BUILD/dnsmasq.tar.xz"
tar -xJf "$BUILD/dnsmasq.tar.xz" -C "$BUILD"

echo "=== make (arch=${ARCH}) ==="
cd "$SRC"
make CFLAGS="-arch ${ARCH} -O2" LDFLAGS="-arch ${ARCH}" -j"$(sysctl -n hw.ncpu)" >/dev/null
BIN="$SRC/src/dnsmasq"
cd "$ROOT"

echo "=== otool -L (relocatability gate) ==="
otool -L "$BIN"
BAD=$(otool -L "$BIN" | tail -n +2 | awk '{print $1}' \
        | grep -vE '^(/usr/lib/|/System/|@rpath/|@executable_path/|@loader_path/)' || true)
if [[ -n "$BAD" ]]; then echo "  ✗ leaked dylib refs:"; echo "$BAD" | sed 's/^/    /'; exit 1; fi
echo "  ✓ no fragile dylib refs"

cp "$BIN" "$OUT/dnsmasq"
chmod +x "$OUT/dnsmasq"
# Ad-hoc sign so BinaryStager's codesign verify passes; Phase 9 replaces with Developer ID.
codesign --force --sign - "$OUT/dnsmasq"
echo "=== vendored → $OUT/dnsmasq ($(lipo -archs "$OUT/dnsmasq" 2>/dev/null || echo "$ARCH")) ==="
"$OUT/dnsmasq" --version | head -1
echo "DNSMASQ BUILD OK"
