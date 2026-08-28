#!/usr/bin/env bash
# Live database integration matrix: boots each MySQL/MariaDB engine on :3306 from an isolated
# temp datadir, runs the KTStack DB integration suite against it, then restores the managed
# service. The suite is opt-in (KTSTACK_DB_IT=1) and connects over TCP 127.0.0.1:3306 as
# root with no password, exactly like the managed .managedMySQL profile the app ships.
#
# Too slow and too stateful for the commit/push hooks; run it per session and before a release.
# See Packages/Features/KTDatabasePlugin/Tests/KTDatabasePluginTests/*IntegrationTests.swift.
#
# Usage: scripts/db-integration-test.sh [mysql|mariadb]   # default: both, in matrix order
#   ENGINES="mysql mariadb"  override the matrix
#
# Safety: engines run against a throwaway datadir under a no-space temp path, never the user's
# real ~/Library/Application Support/KTStack/data. Port 3306 is freed by booting out the managed
# launchd jobs first, and the previously loaded managed engine is bootstrapped back on exit.
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$PWD"

APPSUP="$HOME/Library/Application Support/KTStack"
RUNTIMES="$APPSUP/runtimes"
LAUNCHD="$APPSUP/launchd"
UID_NUM="$(id -u)"
WORK="/tmp/ktstack-dbit"
PKG="Packages/Features/KTDatabasePlugin"

# Live classes that exercise a real MySQL/MariaDB engine (excludes Mongo/Postgres integration).
FILTERS=(
    MySQLDriverIntegrationTests
    MySQLDriverCRUDTests
    MySQLDriverCancelTests
    MySQLBatchCommitIntegrationTests
    MySQL100kProfilingIntegrationTests
    ReadOnlySessionTests
    DumpServiceTests
)

log()  { printf '\n=== %s ===\n' "$1"; }
ok()   { printf '✅ %s\n' "$1"; }
fail() { printf '❌ %s\n' "$1" >&2; }

# Highest installed version dir matching a prefix, e.g. latest_version mysql 8.
latest_version() {
    local kind="$1" major="$2"
    /bin/ls -1 "$RUNTIMES/$kind" 2>/dev/null \
        | grep -E "^${major}\." \
        | sort -t. -k1,1n -k2,2n -k3,3n \
        | tail -1
}

# Managed jobs that own :3306; recorded so we can restore whatever was loaded.
RESTORE_JOBS=()
record_managed_state() {
    for job in com.ktstack.mysql com.ktstack.mariadb; do
        if launchctl print "gui/$UID_NUM/$job" >/dev/null 2>&1; then
            RESTORE_JOBS+=("$job")
        fi
    done
}

free_port_3306() {
    for job in com.ktstack.mysql com.ktstack.mariadb; do
        launchctl bootout "gui/$UID_NUM/$job" >/dev/null 2>&1 || true
    done
    # Wait for the port to clear so the throwaway engine can bind it.
    for _ in $(seq 1 30); do
        lsof -nP -iTCP:3306 -sTCP:LISTEN >/dev/null 2>&1 || return 0
        sleep 0.5
    done
    fail "port 3306 still held after booting out managed engines"
    return 1
}

CURRENT_PID=""
CURRENT_ADMIN=""
CURRENT_SOCK=""

stop_current_engine() {
    [[ -n "$CURRENT_PID" ]] || return 0
    "$CURRENT_ADMIN" -u root --socket="$CURRENT_SOCK" shutdown >/dev/null 2>&1 || kill "$CURRENT_PID" >/dev/null 2>&1 || true
    for _ in $(seq 1 40); do
        kill -0 "$CURRENT_PID" >/dev/null 2>&1 || break
        sleep 0.5
    done
    kill -9 "$CURRENT_PID" >/dev/null 2>&1 || true
    CURRENT_PID=""
}

cleanup() {
    stop_current_engine
    rm -rf "$WORK" 2>/dev/null || true
    for job in "${RESTORE_JOBS[@]:-}"; do
        [[ -f "$LAUNCHD/$job.plist" ]] || continue
        launchctl bootstrap "gui/$UID_NUM" "$LAUNCHD/$job.plist" >/dev/null 2>&1 || true
    done
}
trap cleanup EXIT

wait_for_ready() {
    local admin="$1" sock="$2"
    for _ in $(seq 1 60); do
        "$admin" -u root --socket="$sock" ping >/dev/null 2>&1 && return 0
        sleep 0.5
    done
    return 1
}

# Boot one engine on :3306 against a fresh datadir, then run the suite. $1=mysql|mariadb.
run_engine() {
    local flavor="$1" major version bindir base datadir sock cnf logf admin server
    case "$flavor" in
        mysql)   major=8;  server=mysqld;   admin=mysqladmin ;;
        mariadb) major=11; server=mariadbd; admin=mariadb-admin ;;
        *) fail "unknown engine '$flavor'"; return 2 ;;
    esac

    version="$(latest_version "$flavor" "$major")"
    if [[ -z "$version" ]]; then
        fail "$flavor $major.x not installed under $RUNTIMES/$flavor (on-demand engine; install it first)"
        return 1
    fi
    base="$RUNTIMES/$flavor/$version"
    bindir="$base/bin"
    if [[ ! -x "$bindir/$server" ]]; then
        fail "missing $bindir/$server"
        return 1
    fi

    log "$flavor $version — init throwaway datadir"
    datadir="$WORK/$flavor/data"
    sock="$WORK/$flavor/m.sock"   # short path: unix socket path limit is ~104 chars
    logf="$WORK/$flavor/engine.log"
    cnf="$WORK/$flavor/my.cnf"
    rm -rf "$WORK/$flavor"
    mkdir -p "$datadir"

    {
        echo "[mysqld]"
        echo "port = 3306"
        echo "bind-address = 127.0.0.1"
        echo "datadir = $datadir"
        echo "socket = $sock"
        echo "log-error = $logf"
        echo "pid-file = $WORK/$flavor/m.pid"
        [[ "$flavor" == mariadb ]] && echo "basedir = $base"
    } > "$cnf"

    if [[ "$flavor" == mysql ]]; then
        "$bindir/$server" --defaults-file="$cnf" --initialize-insecure >>"$logf" 2>&1 \
            || { fail "mysqld --initialize-insecure failed; see $logf"; tail -20 "$logf" >&2; return 1; }
    else
        # mariadb-install-db word-splits $basedir; the runtime path has spaces, so run it through a
        # no-space symlink (same reason the app does, see MySQLController.initializeMariaDB).
        local linkbase="$WORK/mariadb-base"
        rm -f "$linkbase"; ln -s "$base" "$linkbase"
        "$linkbase/scripts/mariadb-install-db" \
            --basedir="$linkbase" --datadir="$datadir" \
            --auth-root-authentication-method=normal --skip-test-db >>"$logf" 2>&1 \
            || { fail "mariadb-install-db failed; see $logf"; tail -20 "$logf" >&2; return 1; }
    fi

    log "$flavor $version — start on :3306"
    "$bindir/$server" --defaults-file="$cnf" >>"$logf" 2>&1 &
    CURRENT_PID=$!
    CURRENT_ADMIN="$bindir/$admin"
    CURRENT_SOCK="$sock"
    if ! wait_for_ready "$bindir/$admin" "$sock"; then
        fail "$flavor did not accept connections; see $logf"
        tail -30 "$logf" >&2
        return 1
    fi
    ok "$flavor $version listening on :3306"

    # Seed the 100k profiling fixture so MySQL100kProfilingIntegrationTests runs for real instead of
    # skipping. Cross-join of ten 0-9 rows to 10^5 rows, no recursion-depth limit on either engine.
    log "$flavor $version — seed kt_sample_100k.events (100000 rows)"
    local digits="(SELECT 0 n UNION SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4 UNION SELECT 5 UNION SELECT 6 UNION SELECT 7 UNION SELECT 8 UNION SELECT 9)"
    "$bindir/mysql" -u root --socket="$sock" <<SQL >>"$logf" 2>&1 || { fail "seeding kt_sample_100k failed; see $logf"; tail -20 "$logf" >&2; return 1; }
DROP DATABASE IF EXISTS kt_sample_100k;
CREATE DATABASE kt_sample_100k;
CREATE TABLE kt_sample_100k.events (id INT NOT NULL AUTO_INCREMENT PRIMARY KEY, payload VARCHAR(64));
INSERT INTO kt_sample_100k.events (payload)
SELECT CONCAT('e', a.n + b.n*10 + c.n*100 + d.n*1000 + e.n*10000)
FROM $digits a CROSS JOIN $digits b CROSS JOIN $digits c CROSS JOIN $digits d CROSS JOIN $digits e;
SQL
    ok "$flavor $version seeded 100000 rows"

    log "$flavor $version — DB integration suite (KTSTACK_DB_IT=1)"
    local filter_args=() cls
    for cls in "${FILTERS[@]}"; do filter_args+=(--filter "$cls"); done
    local rc=0
    # KTSTACK_DB_IT_BINDIR lets DumpServiceTests resolve the real mysqldump/mysql for a live round-trip.
    KTSTACK_DB_IT=1 KTSTACK_DB_IT_BINDIR="$bindir" PATH="$bindir:$PATH" \
        swift test --package-path "$PKG" "${filter_args[@]}" || rc=$?

    stop_current_engine
    if [[ $rc -ne 0 ]]; then
        fail "$flavor $version integration suite FAILED (rc=$rc)"
        return 1
    fi
    ok "$flavor $version integration suite passed"
    return 0
}

ENGINES="${ENGINES:-${1:-mysql mariadb}}"
record_managed_state
free_port_3306 || exit 1

rc=0
declare -a RESULTS=()
for e in $ENGINES; do
    if run_engine "$e"; then
        RESULTS+=("$e: PASS")
    else
        RESULTS+=("$e: FAIL")
        rc=1
    fi
done

log "matrix result"
printf '%s\n' "${RESULTS[@]}"
[[ $rc -eq 0 ]] && ok "DB integration matrix passed" || fail "DB integration matrix had failures"
exit $rc
