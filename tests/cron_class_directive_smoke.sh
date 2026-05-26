#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
fail(){ echo "[FAIL] $*" >&2; exit 1; }
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
spool="$tmp/spool"; state="$tmp/state"; mkdir -p "$spool" "$state"
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
export QUEUEBASH_CRON_SPOOL_DIR="$spool"
export QUEUEBASH_CRON_STATE_DIR="$state"
export QUEUEBASH_ROOT="$tmp/qroot"
source ./queuebash.sh
mkdir -p "$QUEUEBASH_ROOT/classes"
cat > "$QUEUEBASH_ROOT/classes/CRON_SPECIAL.env" <<'CLASS'
CLASS_ALLOW_PARALLEL=1
CLASS_MAX_CONCURRENT=1
CLASS_DEFAULT_RUNNER=auto
CLASS_DEFAULT_SANDBOX_LEVEL=strict
CLASS_DEFAULT_SECCOMP_PROFILE=off
CLASS
cat > "$spool/$(id -un)" <<'CRON'
# queuebash test
*/2 * * * * echo test
CRON
out="$(queue cron class 1 CRON_SPECIAL)" || fail "queue cron class failed"
grep -q '#class CRON_SPECIAL' "$spool/$(id -un)" || fail "#class directive not inserted"
explain="$(queue cron explain)"
grep -q 'class:    CRON_SPECIAL (explicit #class' <<< "$explain" || fail "cron explain does not show explicit class"
python_out="$(QUEUEBASH_CRON_SPOOL_DIR="$spool" QUEUEBASH_CRON_STATE_DIR="$state" QUEUEBASH_ROOT="$tmp/qroot" QUEUEBASH_SOURCE="$PWD/queuebash.sh" python3 bin/bashqueues-cron-ticker.py --dryrun --now 2026-05-25T20:02:00 2>&1)"
grep -q 'class=CRON_SPECIAL' <<< "$python_out" || fail "ticker dryrun did not use explicit class: $python_out"
queue cron class 1 --clear >/dev/null
grep -q '#class CRON_SPECIAL' "$spool/$(id -un)" && fail "#class directive not cleared"
echo "[PASS] cron class directive can be set, explained, used by ticker, and cleared"
