#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/spool" "$tmp/system" "$tmp/state"
cat > "$tmp/spool/$(id -un)" <<EOF
* * * * * echo hello-from-cron-bridge
EOF
out="$(python3 bin/bashqueues-cron-ticker.py --spool-dir "$tmp/spool" --system-dir "$tmp/system" --state-dir "$tmp/state" --now 2026-05-24T12:34:00 --dryrun)"
case "$out" in
  *DRYRUN*hello-from-cron-bridge*) echo '[PASS] cron ticker dryrun matches and submits due entries' ;;
  *) echo "$out" >&2; echo '[FAIL] cron ticker dryrun did not show expected submission' >&2; exit 1 ;;
esac
