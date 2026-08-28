#!/usr/bin/env bash
# Two jobs:
# 1. Audit app-linked SPM dependencies. KTStack root is MIT, so every dependency
#    linked into an app target must be permissive. Copyleft (AGPL/GPL/LGPL/SSPL)
#    or unknown app-linked code fails the audit. Bundled engines (mysqld, dnsmasq,
#    redis, ...) are separately distributed executables, not app-linked; they keep
#    their own licenses via the NOTICES table + source offer below.
# 2. Generate NOTICES.txt: attribution + license identifiers for every
#    redistributed component, plus a written offer of source for the copyleft ones.
#
# Usage:
#   license-audit.sh [OUT]        # audit SPM deps, then write NOTICES.txt (default OUT: ROOT/NOTICES.txt)
#   license-audit.sh --audit-only # audit SPM deps only, no NOTICES
#   license-audit.sh --self-test  # prove the audit accepts current deps and rejects an AGPL/unknown fixture
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

# ---- SPM app-linked dependency allowlist (identity|SPDX license) ----
# App-target pins live in the workspace + KTDatabasePlugin Package.resolved.
SPM_ALLOW=(
  "mysql-nio|MIT"
  "postgres-nio|Apache-2.0"
  "grdb.swift|MIT"
  "mongokitten|MIT"
  "bson|MIT"
  "dnsclient|MIT"
  "sparkle|MIT"
  "swift-algorithms|Apache-2.0"
  "swift-async-algorithms|Apache-2.0"
  "swift-asn1|Apache-2.0"
  "swift-atomics|Apache-2.0"
  "swift-collections|Apache-2.0"
  "swift-crypto|Apache-2.0"
  "swift-distributed-tracing|Apache-2.0"
  "swift-log|Apache-2.0"
  "swift-metrics|Apache-2.0"
  "swift-nio|Apache-2.0"
  "swift-nio-ssl|Apache-2.0"
  "swift-nio-transport-services|Apache-2.0"
  "swift-numerics|Apache-2.0"
  "swift-service-context|Apache-2.0"
  "swift-service-lifecycle|Apache-2.0"
  "swift-system|Apache-2.0"
)

# Override with SPM_RESOLVED (colon-separated paths) for tests; defaults to the app-target pins.
if [ -n "${SPM_RESOLVED:-}" ]; then
  IFS=':' read -r -a SPM_RESOLVED_FILES <<< "$SPM_RESOLVED"
else
  SPM_RESOLVED_FILES=(
    "$ROOT/KTStack.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"
    "$ROOT/Packages/Features/KTDatabasePlugin/Package.resolved"
  )
fi

spm_allowed_license() {
  local id="$1" row
  for row in "${SPM_ALLOW[@]}"; do
    if [ "${row%%|*}" = "$id" ]; then printf '%s' "${row#*|}"; return 0; fi
  done
  return 1
}

# LGPL is excluded too: static linking into an app target carries relinking/source duties.
is_copyleft() {
  case "$1" in
    *AGPL*|*GPL*|*SSPL*) return 0 ;;
    *) return 1 ;;
  esac
}

# stdin: "identity|license" lines (license "UNKNOWN" when not allowlisted). Non-zero on any violation.
audit_identities() {
  local fail=0 id lic
  while IFS='|' read -r id lic; do
    [ -z "$id" ] && continue
    if [ "$lic" = "UNKNOWN" ]; then
      echo "FAIL: app-linked SPM dependency '$id' is not in the license allowlist (unknown provenance)" >&2
      fail=1
    elif is_copyleft "$lic"; then
      echo "FAIL: app-linked SPM dependency '$id' is copyleft ($lic); not allowed in an MIT app target" >&2
      fail=1
    fi
  done
  return $fail
}

collect_spm_pairs() {
  local f id lic
  for f in "${SPM_RESOLVED_FILES[@]}"; do
    [ -f "$f" ] || continue
    grep -E '"identity"' "$f" | sed -E 's/.*: *"([^"]+)".*/\1/' | while read -r id; do
      if lic="$(spm_allowed_license "$id")"; then
        printf '%s|%s\n' "$id" "$lic"
      else
        printf '%s|UNKNOWN\n' "$id"
      fi
    done
  done | sort -u
}

run_audit() {
  local n
  n="$(collect_spm_pairs | wc -l | tr -d ' ')"
  echo "Auditing $n app-linked SPM dependencies..."
  if collect_spm_pairs | audit_identities; then
    echo "SPM license audit passed."
  else
    echo "SPM license audit FAILED. See rejected dependencies above." >&2
    exit 1
  fi
}

self_test() {
  echo "self-test: current dependency set must pass"
  if ! collect_spm_pairs | audit_identities; then
    echo "self-test FAILED: current dependency set was rejected" >&2; exit 1
  fi
  echo "self-test: AGPL fixture must be rejected"
  if printf 'fixture-agpl|AGPL-3.0-only\n' | audit_identities 2>/dev/null; then
    echo "self-test FAILED: AGPL fixture was accepted" >&2; exit 1
  fi
  echo "self-test: unknown fixture must be rejected"
  if printf 'fixture-unknown|UNKNOWN\n' | audit_identities 2>/dev/null; then
    echo "self-test FAILED: unknown fixture was accepted" >&2; exit 1
  fi
  echo "self-test passed: current deps accepted, AGPL and unknown fixtures rejected."
}

# ---- arg parsing ----
MODE="generate"
OUT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --audit-only) MODE="audit" ;;
    --self-test)  MODE="selftest" ;;
    -*) echo "unknown flag: $1" >&2; exit 2 ;;
    *) OUT="$1" ;;
  esac
  shift
done
OUT="${OUT:-$ROOT/NOTICES.txt}"

case "$MODE" in
  selftest) self_test; exit 0 ;;
  audit)    run_audit; exit 0 ;;
  generate) run_audit ;;
esac

# ---- NOTICES.txt generation ----
# component | license (SPDX-ish) | upstream source
COMPONENTS=(
  "nginx|BSD-2-Clause|https://nginx.org/en/download.html"
  "PHP (7.4/8.0/8.1/8.2/8.3/8.4/8.5, php/php-fpm - shivammathur/php bottle, relocated)|PHP-3.01|https://www.php.net/downloads"
  "dnsmasq|GPL-2.0-or-later|https://thekelleys.org.uk/dnsmasq/"
  "mkcert|BSD-3-Clause|https://github.com/FiloSottile/mkcert"
  "Mailpit|MIT|https://github.com/axllent/mailpit"
  "MySQL (mysqld)|GPL-2.0-only|https://dev.mysql.com/downloads/mysql/"
  "MariaDB (mariadbd)|GPL-2.0-only|https://mariadb.org/download/"
  "PostgreSQL|PostgreSQL|https://www.postgresql.org/ftp/source/"
  "Redis (>=7)|SSPL-1.0 / RSALv2|https://github.com/redis/redis"
  "Memcached (server)|BSD-3-Clause|https://memcached.org/"
  "Node.js|MIT (+deps)|https://nodejs.org/dist/"
  "Go (on-demand)|BSD-3-Clause|https://go.dev/dl/"
  "Sparkle|MIT|https://github.com/sparkle-project/Sparkle"
  "OpenSSL (libssl/libcrypto)|Apache-2.0|https://www.openssl.org/source/"
  "ICU (libicu*)|Unicode-3.0|https://github.com/unicode-org/icu"
  "curl (libcurl)|curl (MIT-like)|https://curl.se/download.html"
  "nghttp2/nghttp3 (libnghttp*)|MIT|https://nghttp2.org/"
  "ngtcp2 (libngtcp2*)|MIT|https://github.com/ngtcp2/ngtcp2"
  "libssh2|BSD-3-Clause|https://libssh2.org/"
  "brotli (libbrotli*)|MIT|https://github.com/google/brotli"
  "zstd (libzstd)|BSD-3-Clause OR GPL-2.0|https://github.com/facebook/zstd"
  "zlib (libz)|Zlib|https://zlib.net/"
  "xz/lzma (liblzma)|0BSD|https://tukaani.org/xz/"
  "PostgreSQL client (libpq)|PostgreSQL|https://www.postgresql.org/ftp/source/"
  "SQLite (libsqlite3)|blessing (public domain)|https://www.sqlite.org/download.html"
  "libsodium|ISC|https://github.com/jedisct1/libsodium"
  "argon2 (libargon2)|CC0-1.0 OR Apache-2.0|https://github.com/P-H-C/phc-winner-argon2"
  "oniguruma (libonig)|BSD-2-Clause|https://github.com/kkos/oniguruma"
  "PCRE2 (libpcre2)|BSD-3-Clause|https://github.com/PCRE2Project/pcre2"
  "libzip|BSD-3-Clause|https://libzip.org/"
  "MIT Kerberos (libkrb5/libk5crypto/libcom_err/libgssapi_krb5/libkrb5support)|MIT|https://web.mit.edu/kerberos/"
  "OpenLDAP (libldap/liblber)|OLDAP-2.8|https://www.openldap.org/software/download/"
  "libffi|MIT|https://github.com/libffi/libffi"
  "GD (libgd)|BSD-like|https://libgd.github.io/"
  "FreeType (libfreetype)|FTL OR GPL-2.0|https://freetype.org/"
  "fontconfig (libfontconfig)|MIT|https://www.freedesktop.org/wiki/Software/fontconfig/"
  "libpng|PNG-2.0|http://www.libpng.org/pub/png/libpng.html"
  "libjpeg-turbo (libjpeg)|IJG OR BSD-3-Clause|https://libjpeg-turbo.org/"
  "libtiff|libtiff (BSD-like)|https://libtiff.gitlab.io/libtiff/"
  "libwebp/sharpyuv|BSD-3-Clause|https://github.com/webmproject/libwebp"
  "aom (libaom)|BSD-2-Clause|https://aomedia.googlesource.com/aom/"
  "dav1d (libdav1d)|BSD-2-Clause|https://code.videolan.org/videolan/dav1d"
  "libavif|BSD-2-Clause|https://github.com/AOMediaCodec/libavif"
  "libvmaf|BSD-2-Clause-Patent|https://github.com/Netflix/vmaf"
  "tidy-html5 (libtidy)|W3C (MIT-like)|https://github.com/htacg/tidy-html5"
  "unixODBC (libodbc)|LGPL-2.1-or-later|https://www.unixodbc.org/"
  "FreeTDS (libsybdb)|LGPL-2.0-or-later|https://www.freetds.org/"
  "GMP (libgmp)|LGPL-3.0-or-later OR GPL-2.0|https://gmplib.org/"
  "GNU gettext (libintl)|LGPL-2.1-or-later|https://www.gnu.org/software/gettext/"
  "GNU Aspell (libaspell/libpspell)|LGPL-2.1-or-later|http://aspell.net/"
  "GNU libtool (libltdl)|LGPL-2.1-or-later|https://www.gnu.org/software/libtool/"
  "ImageMagick (libMagickCore/libMagickWand — imagick ext)|ImageMagick (Apache-2.0-like)|https://imagemagick.org/"
  "Little CMS (liblcms2 — imagick ext)|MIT|https://www.littlecms.com/"
  "libmemcached (memcached ext)|BSD-3-Clause|https://libmemcached.org/"
  "libevent (event ext)|BSD-3-Clause|https://libevent.org/"
  "net-snmp (libnetsnmp — snmp ext)|net-snmp (BSD-like)|https://www.net-snmp.org/"
)
# Copyleft components that require a written offer of source.
SOURCE_OFFER=(
  "dnsmasq" "MySQL (mysqld)" "MariaDB (mariadbd)" "Redis (>=7)"
  "unixODBC (libodbc)" "FreeTDS (libsybdb)" "GMP (libgmp)"
  "GNU gettext (libintl)" "GNU Aspell (libaspell/libpspell)" "GNU libtool (libltdl)"
)

{
  echo "KTStack — Third-Party Notices"
  echo "Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "KTStack is distributed free of charge as open-source software."
  echo
  echo "== Redistributed components =="
  for row in "${COMPONENTS[@]}"; do
    IFS='|' read -r name lic src <<< "$row"
    printf -- "- %s\n    License: %s\n    Source:  %s\n" "$name" "$lic" "$src"
  done
  echo
  echo "== Written offer of source (GPL / SSPL components) =="
  echo "For the following components, KTStack provides the complete corresponding source code."
  echo "The exact upstream version + build recipe for each is in scripts/build-*-relocatable.sh and"
  echo "scripts/build-php-versions.sh; request a copy at the project repository or the contact below."
  for c in "${SOURCE_OFFER[@]}"; do echo "  - $c"; done
  echo
  echo "Contact: https://github.com/KTStackAPP/KTStack"
  echo
  echo "Full license texts for each component are available at the Source URLs above and are included"
  echo "with the corresponding upstream distributions."
} > "$OUT"

echo "wrote $OUT ($(wc -l < "$OUT" | tr -d ' ') lines)"
