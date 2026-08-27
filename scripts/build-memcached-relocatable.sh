#!/usr/bin/env bash
# Build a relocatable memcached from source and produce an on-demand artifact (tar.gz + sha256).
# Memcached ships on-demand (installed via the UI), so this does NOT copy into Resources/bin — it
# stages a self-contained memcached-<ver>/ tree (bin + vendored libevent) for a release host.
#
# Relocatability: memcached links libevent (Homebrew) → vendored into lib/ with the install name
# rewritten to @loader_path/../lib via `vendor_nonsystem_dylibs`. The binary is re-run from a moved
# copy and probed over TCP to PROVE relocation.
#
# Licensing: Memcached and libevent are both BSD-3-Clause. NOTICES ship via license-audit.sh.
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$PWD"

MEMCACHED_VER="${MEMCACHED_VER:-1.6.38}"
ARCH="${ARCH:-$(uname -m)}"
ARTIFACTS="${ARTIFACTS:-$ROOT/.build-cache/artifacts}"
BUILD="${BUILD:-$ROOT/.build-cache/memcached-$ARCH-$MEMCACHED_VER}"
PREFIX="$BUILD/buildroot"
source "$ROOT/scripts/lib-relocatable.sh"

BREW="$(brew_for_arch)"
LIBEVENT_PREFIX="${LIBEVENT_PREFIX:-$($BREW --prefix libevent 2>/dev/null || true)}"
[[ -n "$LIBEVENT_PREFIX" ]] || { echo "libevent required (brew install libevent)" >&2; exit 2; }

echo "=== memcached build — ${MEMCACHED_VER} (${ARCH}) ==="
mkdir -p "$BUILD" "$ARTIFACTS"
cd "$BUILD"

SRC="memcached-$MEMCACHED_VER"
if [[ ! -d "$SRC" ]]; then
    echo "=== fetch memcached source ==="
    curl -fsSL --retry 5 --retry-delay 3 --retry-all-errors \
        "https://memcached.org/files/memcached-${MEMCACHED_VER}.tar.gz" -o memcached.tgz
    tar -xf memcached.tgz
fi

if [[ ! -x "$PREFIX/bin/memcached" ]]; then
    echo "=== configure + make (arch=${ARCH}) ==="
    ( cd "$SRC" && ./configure --prefix="$PREFIX" \
        --with-libevent="$LIBEVENT_PREFIX" --disable-docs \
        CFLAGS="-arch ${ARCH}" LDFLAGS="-arch ${ARCH}" >/dev/null )
    make -C "$SRC" -j"$(sysctl -n hw.ncpu)" >/dev/null
    make -C "$SRC" install >/dev/null
fi

echo "=== stage self-contained artifact tree ==="
STAGE="$(mktemp -d)"; TOP="$STAGE/memcached-$MEMCACHED_VER"
mkdir -p "$TOP/bin"
cp "$PREFIX/bin/memcached" "$TOP/bin/memcached"

echo "=== vendor libevent + fix install names ==="
vendor_nonsystem_dylibs "$TOP/bin/memcached" "$TOP/lib"

echo "=== strip + relocatability gate ==="
strip -x "$TOP/bin/memcached" 2>/dev/null || true
relocatable_gate "$TOP/bin/memcached"
for d in "$TOP"/lib/*.dylib; do [[ -e "$d" ]] && relocatable_gate "$d"; done
ad_hoc_sign "$TOP/bin/memcached" "$TOP"/lib/*.dylib 2>/dev/null || ad_hoc_sign "$TOP/bin/memcached"

echo "=== PROVE relocation: serve a query from a moved copy ==="
RELOC="$(mktemp -d)/moved"; mkdir -p "$RELOC"; cp -R "$TOP" "$RELOC/"
MDIR="$RELOC/memcached-$MEMCACHED_VER"; PIDF="$(mktemp -d)/pid"
"$MDIR/bin/memcached" -l 127.0.0.1 -p 11299 -d -P "$PIDF"
sleep 1
if printf 'version\r\nquit\r\n' | nc 127.0.0.1 11299 | grep -qi 'VERSION'; then
    echo "  ✓ memcached served a query from moved path"
    [[ -f "$PIDF" ]] && kill "$(cat "$PIDF")" 2>/dev/null || true
else
    echo "  ✗ memcached query failed from moved path" >&2
    [[ -f "$PIDF" ]] && kill "$(cat "$PIDF")" 2>/dev/null || true
    exit 1
fi
rm -rf "$RELOC"

package_dir "$TOP" "$ARTIFACTS"
rm -rf "$STAGE"
echo "MEMCACHED BUILD OK"
