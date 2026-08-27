#!/usr/bin/env bash
# Build a relocatable MariaDB server (mariadbd) from source and produce an on-demand artifact
# (tar.gz + sha256). MariaDB ships on-demand (installed via the UI), so this does NOT copy into
# Resources/bin — it stages a self-contained mariadb-<ver>/ tree (bin + lib + share + scripts) for a
# release host. MariaDB shares port 3306 with MySQL (only one 3306 engine runs at a time).
#
# HEAVY: CMake + a full C++ compile. Expect ~30-60 min and several GB of scratch per arch.
# Run it directly when you want the artifact: `scripts/build-mariadb-relocatable.sh`.
#
# Relocatability: mariadbd derives its basedir from the executable path, but the plugin dir and the
# mariadb-install-db bootstrap need it spelled out — MySQLController(flavor: .mariadb) passes
# `--basedir`/`basedir=` explicitly. The one external dep is OpenSSL (Homebrew) → vendored into lib/
# with install names rewritten to @loader_path/../lib via `vendor_nonsystem_dylibs`. The build is
# re-extracted to a different path and mariadb-install-db is run to PROVE relocation.
#
# Licensing: MariaDB is GPLv2. NOTICES + written source offer ship via license-audit.sh.
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$PWD"

MARIADB_VER="${MARIADB_VER:-11.4.4}"
MARIADB_SERIES="${MARIADB_SERIES:-11.4}"
ARCH="${ARCH:-$(uname -m)}"
ARTIFACTS="${ARTIFACTS:-$ROOT/.build-cache/artifacts}"
BUILD="${BUILD:-$ROOT/.build-cache/mariadb-$ARCH-$MARIADB_VER}"
PREFIX="$BUILD/buildroot"
source "$ROOT/scripts/lib-relocatable.sh"

# Pick the arch-matched cmake explicitly, never PATH: the host runs a cmake per Homebrew, and a plain
# `cmake` can resolve to the sibling-arch one. cmake's host-CPU detection drives the mysys crc32 source
# gate, so an x86_64 cmake on an arm64 build compiles crc32c_amd64.cc (x86 intrinsics) and fails, and a
# cross-build's CMAKE_SYSTEM_PROCESSOR is forced back to the host anyway. Run the target-arch cmake so
# detection matches the target: arm64 cmake for arm64, x86_64 cmake under Rosetta for x86_64.
if [[ "$ARCH" == "x86_64" && "$(uname -m)" == "arm64" ]]; then
    CMAKE=(arch -x86_64 /usr/local/bin/cmake)
elif [[ "$ARCH" == "arm64" ]]; then
    CMAKE=(/opt/homebrew/bin/cmake)
else
    CMAKE=(cmake)
fi
"${CMAKE[@]}" --version >/dev/null 2>&1 || { echo "cmake required for $ARCH (brew install cmake)" >&2; exit 2; }
BREW="$(brew_for_arch)"
OPENSSL_PREFIX="${OPENSSL_PREFIX:-$($BREW --prefix openssl@3 2>/dev/null || true)}"
[[ -n "$OPENSSL_PREFIX" ]] || { echo "openssl@3 required (brew install openssl@3)" >&2; exit 2; }

echo "=== MariaDB build — ${MARIADB_VER} (${ARCH}) — HEAVY, ~30-60 min ==="
mkdir -p "$BUILD" "$ARTIFACTS"
cd "$BUILD"

SRC="mariadb-$MARIADB_VER"
if [[ ! -d "$SRC" ]]; then
    echo "=== fetch mariadb source ($MARIADB_VER) ==="
    # Source tarball is large; HTTP/2 CANCEL flakes on archive.mariadb.org, so retry over HTTP/1.1.
    curl -fsSL --http1.1 --retry 5 --retry-delay 3 --retry-all-errors \
        "https://archive.mariadb.org/mariadb-${MARIADB_VER}/source/mariadb-${MARIADB_VER}.tar.gz" -o mariadb.tgz
    tar -xf mariadb.tgz
fi

if [[ ! -x "$PREFIX/bin/mariadbd" ]]; then
    echo "=== cmake configure (lean: storage-heavy plugins off) ==="
    # Pin the active Xcode SDK: mixed CommandLineTools/Xcode SDKs make libc++ <cstddef> fail to find its
    # sibling <stddef.h> and the build dies early in gen_lex_hash. One coherent sysroot fixes it.
    SDKROOT_PATH="$(xcrun --show-sdk-path)"
    # Point cmake at the arch-correct Homebrew root so zstd/zlib resolve to the target arch, not the sibling
    # Homebrew (arm64 build must not pick /usr/local x86_64 libzstd, and vice versa).
    BREW_ROOT="$($BREW --prefix)"
    # Bundled pcre2/libfmt/zlib keep the link surface free of external dylibs. If cmake can't fetch them
    # offline, swap -DWITH_PCRE=bundled → =system and vendor libpcre2-8.dylib after staging.
    "${CMAKE[@]}" -S "$SRC" -B "$BUILD/cmbuild" \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_OSX_ARCHITECTURES="$ARCH" \
        -DCMAKE_SYSTEM_PROCESSOR="$ARCH" \
        -DCMAKE_OSX_SYSROOT="$SDKROOT_PATH" \
        -DCMAKE_INSTALL_PREFIX="$PREFIX" \
        -DCMAKE_PREFIX_PATH="$BREW_ROOT" \
        -DWITH_SSL="$OPENSSL_PREFIX" \
        -DWITH_PCRE=bundled -DWITH_LIBFMT=bundled -DWITH_ZLIB=bundled \
        -DWITH_UNIT_TESTS=OFF -DWITH_WSREP=OFF \
        -DPLUGIN_COLUMNSTORE=NO -DPLUGIN_ROCKSDB=NO -DPLUGIN_SPIDER=NO \
        -DPLUGIN_MROONGA=NO -DPLUGIN_CONNECT=NO -DPLUGIN_OQGRAPH=NO \
        -DPLUGIN_S3=NO -DPLUGIN_TOKUDB=NO \
        -DPLUGIN_AUTH_PAM=NO -DPLUGIN_AUTH_PAM_V1=NO \
        -DINSTALL_MYSQLTESTDIR= >/dev/null
    echo "=== make + install (this is the long part) ==="
    "${CMAKE[@]}" --build "$BUILD/cmbuild" -j"$(sysctl -n hw.ncpu)" >/dev/null
    "${CMAKE[@]}" --install "$BUILD/cmbuild" >/dev/null
fi

echo "=== stage self-contained artifact tree ==="
STAGE="$(mktemp -d)"; TOP="$STAGE/mariadb-$MARIADB_VER"
mkdir -p "$TOP"
cp -R "$PREFIX/bin" "$TOP/bin"
cp -R "$PREFIX/lib" "$TOP/lib"
cp -R "$PREFIX/share" "$TOP/share"
cp -R "$PREFIX/scripts" "$TOP/scripts" 2>/dev/null || true
# The install-db bootstrap can live under bin/ or scripts/ depending on packaging; make sure both the
# script and a scripts/ copy exist since MySQLController(flavor: .mariadb) runs scripts/mariadb-install-db.
if [[ ! -x "$TOP/scripts/mariadb-install-db" && -x "$TOP/bin/mariadb-install-db" ]]; then
    mkdir -p "$TOP/scripts"; cp "$TOP/bin/mariadb-install-db" "$TOP/scripts/mariadb-install-db"
fi

echo "=== drop test/embedded binaries (smaller artifact) ==="
rm -f "$TOP"/bin/mariadb-test* "$TOP"/bin/mysql_client_test* "$TOP"/bin/*embedded* 2>/dev/null || true

echo "=== mysql* client aliases (11.x renamed binaries; controllers/tools use both names) ==="
_link() { [[ -e "$TOP/bin/$1" || ! -e "$TOP/bin/$2" ]] || ln -sf "$2" "$TOP/bin/$1"; }
_link mysql mariadb
_link mysqldump mariadb-dump
_link mysqld mariadbd
_link mysqladmin mariadb-admin

echo "=== vendor OpenSSL + fix install names (ALL bin tools) ==="
for b in "$TOP"/bin/*; do
    [[ -L "$b" ]] && continue
    file -b "$b" | grep -q "Mach-O" || continue
    vendor_nonsystem_dylibs "$b" "$TOP/lib"
done

echo "=== vendor plugins (lib/plugin/*.so reach lib/ via @loader_path/..) ==="
for p in "$TOP"/lib/plugin/*.so; do
    [[ -e "$p" ]] || continue
    file -b "$p" | grep -q "Mach-O" || continue
    while IFS= read -r ref; do
        case "$ref" in /usr/lib/*|/System/*|@*) continue ;; esac
        base="$(basename "$ref")"
        [[ -f "$TOP/lib/$base" ]] || cp "$ref" "$TOP/lib/$base" 2>/dev/null || continue
        install_name_tool -change "$ref" "@loader_path/../$base" "$p" 2>/dev/null || true
    done < <(otool -L "$p" | tail -n +2 | awk '{print $1}')
done

echo "=== strip + relocatability gate ==="
for b in "$TOP"/bin/* "$TOP"/lib/plugin/*.so; do
    [[ -e "$b" && ! -L "$b" ]] || continue
    file -b "$b" | grep -q "Mach-O" || continue
    strip -x "$b" 2>/dev/null || true
    relocatable_gate "$b"
done
ad_hoc_sign "$TOP/bin/mariadbd" "$TOP"/lib/*.dylib 2>/dev/null || ad_hoc_sign "$TOP/bin/mariadbd"

echo "=== PROVE relocation: init + query from a moved copy ==="
RELOC="$(mktemp -d)/moved"; mkdir -p "$RELOC"; cp -R "$TOP" "$RELOC/"
MDIR="$RELOC/mariadb-$MARIADB_VER"; DATA="$(mktemp -d)/data"; SOCK="$(mktemp -d)/s"
if ! "$MDIR/scripts/mariadb-install-db" \
        --basedir="$MDIR" --datadir="$DATA" \
        --auth-root-authentication-method=normal --skip-test-db >/tmp/mariadb-reloc.log 2>&1; then
    echo "  ✗ mariadb-install-db failed from moved path:"; tail -12 /tmp/mariadb-reloc.log; exit 1
fi
"$MDIR/bin/mariadbd" --no-defaults --basedir="$MDIR" --datadir="$DATA" \
    --port=33099 --socket="$SOCK" --skip-grant-tables >/tmp/mariadb-run.log 2>&1 &
MPID=$!
_stop() { kill "$MPID" 2>/dev/null || true; wait "$MPID" 2>/dev/null || true; }
trap _stop EXIT
for _ in $(seq 1 30); do "$MDIR/bin/mariadb" --protocol=tcp --port=33099 -uroot -e 'SELECT VERSION()' >/tmp/mariadb-q.log 2>&1 && break; sleep 1; done
if grep -qiE 'MariaDB' /tmp/mariadb-q.log; then
    echo "  ✓ mariadbd served a query from moved path: $(cat /tmp/mariadb-q.log | tail -1)"
else
    echo "  ✗ mariadbd query failed from moved path:"; tail -12 /tmp/mariadb-run.log; cat /tmp/mariadb-q.log; exit 1
fi
_stop; trap - EXIT
rm -rf "$DATA" "$RELOC"

package_dir "$TOP" "$ARTIFACTS"
rm -rf "$STAGE"
echo "MARIADB BUILD OK"
