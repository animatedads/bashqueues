#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

root="$(mktemp -d)"
spool="$(mktemp -d)"
state="$(mktemp -d)"
trap 'rm -rf "$root" "$spool" "$state"' EXIT
user="$(id -un)"
export QUEUEBASH_ROOT="$root"
export QUEUEBASH_ALLOW_NONINTERACTIVE=1
export QUEUEBASH_SOURCE="$PWD/queuebash.sh"
mkdir -p "$root/classes"
cat > "$root/classes/WEAK.env" <<'CLASS'
CLASS_ALLOW_PARALLEL=1
CLASS_DEFAULT_SANDBOX_LEVEL=off
CLASS
source ./queuebash.sh
queue authorisation generate --admin admin --user "$user" --code C123 -- bash -lc 'echo hello' >/dev/null

cat > "$spool/$user" <<'CRON'
BASHQUEUES_CLASS=WEAK
* * * * * echo hello
CRON
python3 bin/bashqueues-cron-ticker.py --spool-dir "$spool" --system-dir /no-such-dir --state-dir "$state" --now 2026-05-25T04:18:00 --dryrun >"$root/noauth.out" 2>"$root/noauth.err"
grep -q 'class=cron_' "$root/noauth.out"
grep -q 'below crontab minimum' "$root/noauth.err"

cat > "$spool/$user" <<'CRON'
BASHQUEUES_CLASS=WEAK
BASHQUEUES_AUTHORISATION=C123
* * * * * echo hello
CRON
python3 bin/bashqueues-cron-ticker.py --spool-dir "$spool" --system-dir /no-such-dir --state-dir "$state" --now 2026-05-25T04:19:00 --dryrun >"$root/auth.out" 2>"$root/auth.err"
grep -q 'class=WEAK' "$root/auth.out"
! grep -q 'below crontab minimum' "$root/auth.err"
echo '[PASS] cron weak-class requests require command-bound authorisation or fall back to safe generated class'
